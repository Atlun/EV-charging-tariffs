# Helper functions for reading GAMS data files

read_gams(filepath; args...) = CSV.read(filepath, DataFrame; comment="*", delim=' ', ignorerepeated=true, args...)

function read_gams_incfile(filepath; header=false, args...)
    df = CSV.read(filepath, DataFrame; header, comment="*", delim=' ', ignorerepeated=true, silencewarnings=true, args...)
    if header
        # Fix the headers which are offset by 1 - Gams INC tables have no header for the first column  
        rename!(df, ["row_id"; names(df)[1:end-1]])
    end
    return df
end

read_gams_inc(filepath; args...) = read_gams(filepath; header=0, args...)

function read_gams_inc_table(filepath; args...)
    header = read_gams(filepath; limit=0) |> names
    lines = count_comment_lines(filepath)
    read_gams(filepath; header=["rownames"; header], skipto=lines+1, args...)
end

function count_comment_lines(filepath)
    open(filepath, "r") do file
        for (i, line) in enumerate(eachline(file))
            if isempty(line) || startswith(line, "*")
                continue
            end
            return i
        end
        return 0
    end
end

function read_gams_set(filepath)
    # Reads a GAMS set file (list of symbols)
    # Assumes symbols are the first token on each line
    # Skips comments starting with *
    data = String[]
    open(filepath, "r") do file
        for line in eachline(file)
            line = strip(line)
            if isempty(line) || startswith(line, "*")
                continue
            end
            # Split by whitespace and take the first element
            push!(data, split(line)[1])
        end
    end
    return data
end

function read_gams_parameter(filepath)
    # Reads a GAMS parameter file (key-value pairs)
    # Returns a Dictionary or NamedTuple
    data = Dict{String, Float64}()
    open(filepath, "r") do file
        for line in eachline(file)
            line = strip(line)
            if isempty(line) || startswith(line, "*")
                continue
            end
            parts = split(line)
            if length(parts) >= 2
                key = parts[1]
                # Remove any trailing comma if present (GAMS sometimes uses them)
                val_str = replace(parts[2], "," => "")
                try
                    val = parse(Float64, val_str)
                    data[key] = val
                catch
                    # Handle cases where it might not be a number or other issues
                end
            end
        end
    end
    return data
end

function read_gams_table(filepath)
    # Reads a GAMS table (2D matrix)
    # This is more complex. GAMS tables often have headers.
    # We'll use CSV.read with custom options to handle whitespace.
    
    # First, read the file to detect headers and data
    # This is a simplified reader for the specific format seen in eprice_priceareas_2024.INC
    
    # Read all lines
    lines = filter(l -> !isempty(strip(l)) && !startswith(strip(l), "*"), readlines(filepath))
    
    if isempty(lines)
        return DataFrame()
    end

    # The first line usually contains column headers
    header_line = lines[1]
    col_headers = split(header_line)
    
    # The rest are data rows: RowID Val1 Val2 ...
    row_ids = String[]
    data_matrix = zeros(Float64, length(lines)-1, length(col_headers))
    
    for (i, line) in enumerate(lines[2:end])
        parts = split(line)
        push!(row_ids, parts[1])
        for (j, val_str) in enumerate(parts[2:end])
            if j <= length(col_headers)
                data_matrix[i, j] = parse(Float64, val_str)
            end
        end
    end
    
    # Create DataFrame
    df = DataFrame(ID = row_ids)
    for (j, col) in enumerate(col_headers)
        df[!, col] = data_matrix[:, j]
    end
    
    return df
end
