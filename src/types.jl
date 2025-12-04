struct InvalidDataError <: Exception 
    msg::String
end

function Base.showerror(io::IO, e::InvalidDataError)
    print(io, "InvalidDataError: ")
    print(io, e.msg)
end