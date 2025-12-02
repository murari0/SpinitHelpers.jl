using JSON
using EzXML
using TimeZones

function export1D(path, infile="data.dat", inheader="header.xml", outfile="data.json")
    spinit_header = readxml(joinpath(path,inheader));
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
    metaData = Dict("# Scans" => spinit_header_needed["NUMBER_OF_AVERAGES"], "Acquisition Time [s]" => "-", "Experiment Name" => spinit_header_needed["SEQUENCE_NAME"], "Receiver Gain" => spinit_header_needed["RECEIVER_GAIN"]*" dB", "Recycle Delay [s]" => spinit_header_needed["D1"], "Sample" => "-", "Offset [Hz]" => "0.0", "Time Completed" => t, "Original dataset" => path, "raw_Time_Completed" => t, "Alternate reference" => "[]");

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
    @assert sizeof(data) == filesize(joinpath(path,infile)) "Inconsistent data file size"
    open(joinpath(path,infile), "r") do io
        read!(io,data)
    end
    data .= ntoh.(data);            # Spinit data is in Big-Endian format
    dataReal = [data[1:2:end]];
    dataImag = [data[2:2:end]];

    spinit_data_to_ssNake = Dict("dataReal" => dataReal, "dataImag" => dataImag, "hyper" => [0], "freq" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"])], "sw" => [sw], "spec" => [spec], "wholeEcho" => [0.0], "ref" => [parse(Float64,spinit_header_needed["TRANSMIT_FREQ_1"])], "history" => ["RS2D Spinit data loaded from "*pwd()], "metaData" => metaData, "dFilter" => 0.0, "xaxArray" => xaxArray);
    JSON.json(joinpath(path,outfile),spinit_data_to_ssNake)
end