mutable struct DadaClient
    key::Int32
    allocated::Bool
    header::Ref{ipcbuf_t}
    data::Ref{ipcbuf_t}
    function DadaClient(key, allocated, header, data)
        c = new(key, allocated, header, data)
        function cleanup(c)
            if c.allocated
                ipcbuf_destroy(header)
                ipcbuf_destroy(data)
            end
        end
        finalizer(cleanup, c)
    end
end

data_size(client::DadaClient) = ipcbuf_get_bufsz(client.data)
data_count(client::DadaClient) = ipcbuf_get_nbufs(client.data)
header_size(client::DadaClient) = ipcbuf_get_bufsz(client.header)
header_count(client::DadaClient) = ipcbuf_get_nbufs(client.header)

function Base.show(io::IO, client::DadaClient)
    println(io, "Key   : $(client.key)")
    println(io, "Data  : $(data_count(client)) x $(data_size(client)) bytes")
    println(io, "Header: $(header_count(client)) x $(header_size(client)) bytes")
end

"""
    client_connect(key)

Connect to an existing PSRDADA ringbuffer data + header pair, creating a `DadaClient`.
"""
function client_connect(key::Integer)
    data = ipcbuf_connect(key)
    header = ipcbuf_connect(key + 1)
    DadaClient(key, false, header, data)
end

"""
    client_create(key, data_size, data_count, header_size, header_count)

Create a PSRDADA ringbuffer data + header pair, creating a `DadaClient`.
"""
function client_create(key::Integer, data_size::Integer, data_count::Integer, header_size::Integer, header_count::Integer)
    data = ipcbuf_create(key, data_count, data_size)
    header = ipcbuf_create(key + 1, header_count, header_size)
    DadaClient(key, true, header, data)
end

mutable struct ReadBufferIterator
    buf::Ref{ipcbuf_t}
    holding_block::Bool
    function ReadBufferIterator(buf)
        rb = new(buf, false)
        ipcbuf_lock_read(buf)
        function cleanup(rb)
            if rb.holding_block
                ipcbuf_mark_cleared(rb.buf)
            end
            ipcbuf_unlock_read(rb.buf)
        end
        finalizer(cleanup, rb)
    end
end

function next(rb::ReadBufferIterator)
    if rb.holding_block
        ipcbuf_mark_cleared(rb.buf)
        rb.holding_block = false
        if ipcbuf_eod(rb.buf)
            ipcbuf_reset(rb.buf)
            return nothing
        end
    end
    rb.holding_block = true
    ipcbuf_get_next_read(rb.buf)
end

mutable struct WriteBufferIterator
    buf::Ref{ipcbuf_t}
    holding_block::Bool
    function WriteBufferIterator(buf)
        wb = new(buf, false)
        ipcbuf_lock_write(buf)
        function cleanup(wb)
            if wb.holding_block
                ipcbuf_mark_filled(wb.buf, ipcbuf_get_bufsz(wb.buf))
            end
            ipcbuf_unlock_write(wb.buf)
        end
        finalizer(cleanup, wb)
    end
end

function next(wb::WriteBufferIterator)
    if wb.holding_block
        ipcbuf_mark_filled(wb.buf, ipcbuf_get_bufsz(wb.buf))
        wb.holding_block = false
    end
    wb.holding_block = true
    ipcbuf_get_next_write(wb.buf)
end

"""
    read_iter(client)

Get a read-only iterable over the blocks set by `type`.
- `type`: Either `:data` (default) or `:header`
"""
function read_iter(client::DadaClient; type=:data)
    if type == :data
        ReadBufferIterator(client.data)
    elseif type == :header
        ReadBufferIterator(client.header)
    end
end


"""
write_iter(client)

Get a writeable iterable over the blocks set by `type`.
- `type`: Either `:data` (default) or `:header`
"""
function write_iter(client::DadaClient; type=:data)
    if type == :data
        WriteBufferIterator(client.data)
    elseif type == :header
        WriteBufferIterator(client.header)
    end
end

# Export our API
export DadaClient, client_connect, client_create, read_iter, write_iter, data_size, data_count, header_size, header_count, next