function export1D(inpath; infile="data.dat", inheader="header.xml", outpath=inpath, outfile="data.json")
    spinit_header = readxml(joinpath(inpath,inheader));
    spinit_header_needed = Dict("TRANSMIT_FREQ_1"=>"", "SPECTRAL_WIDTH"=>"", "STATE"=>"", "Nb_point"=>"", "NUMBER_OF_AVERAGES"=>"", "SEQUENCE_NAME"=>"", "RECEIVER_GAIN"=>"", "D1"=>"", "ACQUISITION_DATE"=>"");

    params = root(spinit_header).firstelement;

    for h in keys(spinit_header_needed)
        for p in eachelement(params)
            if p.firstelement.content == h
                spinit_header_needed[h] = findfirst("value/value",p).content;
                break
            end
        end
    end
    t = TimeZones.zdt2unix(Integer,parse(ZonedDateTime,spinit_header_needed["ACQUISITION_DATE"]));
    metaData = Dict("# Scans" => spinit_header_needed["NUMBER_OF_AVERAGES"], "Acquisition Time [s]" => "-", "Experiment Name" => spinit_header_needed["SEQUENCE_NAME"], "Receiver Gain" => spinit_header_needed["RECEIVER_GAIN"]*" dB", "Recycle Delay [s]" => spinit_header_needed["D1"], "Sample" => "-", "Offset [Hz]" => "0.0", "Time Completed" => t, "Original dataset" => inpath, "raw_Time_Completed" => t, "Alternate reference" => "[]");

    N = parse(Int32,spinit_header_needed["Nb_point"]);
    sw = parse(Float64,spinit_header_needed["SPECTRAL_WIDTH"]);
    if spinit_header_needed["STATE"] == "" || spinit_header_needed["STATE"] == "0"
        xaxArray = [collect(range(start=0.0,length=N,step=1.0/sw))];
        spec = 0.0;
    else
        xaxArray = [collect(range(start=-sw/2.0,length=N,stop=sw/2.0))];
        spec = 1.0;
    end
    data = Vector{Float32}(undef,2*N);
    if sizeof(data) != filesize(joinpath(inpath,infile))
        throw(InvalidDataError("size of data file inconsistent with dimensions found in header ("*string(N)*" complex points)"))
    end
    open(joinpath(inpath,infile), "r") do io
        read!(io,data)
    end
    data .= ntoh.(data);            # Spinit data is in Big-Endian format
    dataReal = [data[1:2:end]];
    dataImag = [data[2:2:end]];

    spinit_data_to_ssNake = Dict("dataReal" => dataReal, "dataImag" => dataImag, "hyper" => [0], "freq" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"])], "sw" => [sw], "spec" => [spec], "wholeEcho" => [0.0], "ref" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"])], "history" => ["RS2D Spinit data loaded from "*pwd()], "metaData" => metaData, "dFilter" => 0.0, "xaxArray" => xaxArray);
    JSON.json(joinpath(outpath,outfile),spinit_data_to_ssNake)
end

## exportND: Nb_ND is number of points in Nth dimension; DATA_REPRESENTATION has 4 <value> fields and Nth field indicates whether Nth dimension has REAL or COMPLEX points (1 COMPLEX point = 2 float values)

function exportp2D(inpath; infile="data.dat", inheader="header.xml", outpath=inpath, outfile="data.json", x2D::Vector{T}=Float64[]) where T <: Real
    spinit_header = readxml(joinpath(inpath,inheader));
    spinit_header_needed = Dict("TRANSMIT_FREQ_1"=>"", "TRANSMIT_FREQ_2"=>"", "SPECTRAL_WIDTH"=>"", "SPECTRAL_WIDTH_2D"=>"", "STATE"=>"", "Nb_point"=>"", "Nb_2d"=>"", "NUMBER_OF_AVERAGES"=>"", "SEQUENCE_NAME"=>"", "RECEIVER_GAIN"=>"", "D1"=>"", "ACQUISITION_DATE"=>"");

    params = root(spinit_header).firstelement;
    for p in eachelement(params)
        if p.firstelement.content == "DATA_REPRESENTATION"
            if nodecontent.(findall("value/value",p))[2] != "REAL"
                throw(InvalidDataError("full (hypercomplex) 2D files not supported"))
            end
            break
        end
    end

    for h in keys(spinit_header_needed)
        for p in eachelement(params)
            if p.firstelement.content == h
                spinit_header_needed[h] = findfirst("value/value",p).content;
                break
            end
        end
    end
    t = TimeZones.zdt2unix(Integer,parse(ZonedDateTime,spinit_header_needed["ACQUISITION_DATE"]));
    metaData = Dict("# Scans" => spinit_header_needed["NUMBER_OF_AVERAGES"], "Acquisition Time [s]" => "-", "Experiment Name" => spinit_header_needed["SEQUENCE_NAME"], "Receiver Gain" => spinit_header_needed["RECEIVER_GAIN"]*" dB", "Recycle Delay [s]" => spinit_header_needed["D1"], "Sample" => "-", "Offset [Hz]" => "0.0", "Time Completed" => t, "Original dataset" => inpath, "raw_Time_Completed" => t, "Alternate reference" => "[]");

    N1 = parse(Int32,spinit_header_needed["Nb_point"]);
    N2 = parse(Int32,spinit_header_needed["Nb_2d"]);
    sw = parse(Float64,spinit_header_needed["SPECTRAL_WIDTH"]);
    sw2 = parse(Float64,spinit_header_needed["SPECTRAL_WIDTH_2D"]);
    # Ignore STATE for now - bit of a mess to import half-processed data
    if length(x2D) == 0 || length(x2D) != N2
        @warn "No X-axis array matching second dimension provided. Using defaults"
        xaxArray = [collect(range(start=0.0,length=N2,step=1.0)), collect(range(start=0.0,length=N1,step=1.0/sw))];
    else
        xaxArray = [x2D, collect(range(start=-sw/2.0,length=N,stop=sw/2.0))];
    end
    data = Array{Float32,2}(undef,2*N1,N2);
    if sizeof(data) != filesize(joinpath(inpath,infile))
        throw(InvalidDataError("size of data file inconsistent with dimensions found in header ("*string(N)*" complex points)"))
    end
    open(joinpath(inpath,infile), "r") do io
        read!(io,data)
    end
    data .= ntoh.(data);            # Spinit data is in Big-Endian format
    dataReal = [[data[1:2:end,i] for i in 1:N2]];
    dataImag = [[data[2:2:end,i] for i in 1:N2]];

    spinit_data_to_ssNake = Dict("dataReal" => dataReal, "dataImag" => dataImag, "hyper" => [0], "freq" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"]), parse(Float64,spinit_header_needed["TRANSMIT_FREQ_2"])], "sw" => [sw2, sw], "spec" => [0.0, 0.0], "wholeEcho" => [0.0, 0.0], "ref" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_2"]), parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"])], "history" => ["RS2D Spinit data loaded from "*pwd()], "metaData" => metaData, "dFilter" => 0.0, "xaxArray" => xaxArray);
    JSON.json(joinpath(outpath,outfile),spinit_data_to_ssNake)
end