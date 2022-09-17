"""
DadaClient

The handle to the DADA buffer context.
Your best bet is to use this with `with_client` so
everything is cleaned up properly. Otherwise, you need
to make sure to call `cleanup`.
"""
mutable struct DadaClient
    key::Int32
    allocated::Bool
    header::Ref{ipcbuf_t}
    data::Ref{ipcbuf_t}
end

"""
    cleanup(client)

Destroy all the buffers we've allocated (if we did)
"""
function cleanup(client::DadaClient)
    if client.allocated
        ipcbuf_destroy(client.header)
        ipcbuf_destroy(client.data)
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

"""
    with_client(f,key)

Connect to a client with `key` and run the function `f` with
the connected client as it's input. This will automatically perform
cleanup after `f` completes. It's best to use this with the `do` syntax.

# Example
```julia
with_client(key) do client
    # Do things with client
end
```
"""
function with_client(f::Function, key::Integer)
    client = client_connect(key)
    f(client)
    cleanup(client)
end

"""
    with_client(f, key, data_size, data_count, header_size, header_count))

Create a client with `key` and parameters and run the function `f` with
the connected client as it's input. This will automatically perform
cleanup after `f` completes. It's best to use this with the `do` syntax.

# Example
```julia
with_client(key, data_size, data_count, header_size, header_count) do client
    # Do things with client
end
```
"""
function with_client(f::Function, key::Integer, data_size::Integer, data_count::Integer, header_size::Integer, header_count::Integer)
    client = client_create(key, data_size, data_count, header_size, header_count)
    f(client)
    cleanup(client)
end

"""
The iterable over read windows of a connected client.

It's best to get one of these with the context-managed `with_read_iter`,
otherwise you need to call `cleanup` when you're done.
"""
mutable struct ReadBufferIterator
    buf::Ref{ipcbuf_t}
    holding_block::Bool
    function ReadBufferIterator(buf)
        ipcbuf_lock_read(buf)
        new(buf, false)
    end
end

"""
    cleanup(rb)

Cleanup dangling read buffer iterators
"""
function cleanup(rb::ReadBufferIterator)
    if rb.holding_block
        ipcbuf_mark_cleared(rb.buf)
    end
    ipcbuf_unlock_read(rb.buf)
end

"""
    next(rb)

Grab the next block of bytes we can read from
"""
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

"""
The iterable over writeable windows of a connected client.

It's best to get one of these with the context-managed `with_write_iter`,
otherwise you need to call `cleanup` when you're done.
"""
mutable struct WriteBufferIterator
    buf::Ref{ipcbuf_t}
    holding_block::Bool
    function WriteBufferIterator(buf)
        ipcbuf_lock_write(buf)
        new(buf, false)
    end
end

"""
    cleanup(wb)

Cleanup dangling write buffer iterators
"""
function cleanup(wb::WriteBufferIterator)
    if wb.holding_block
        ipcbuf_mark_filled(wb.buf, ipcbuf_get_bufsz(wb.buf))
    end
    ipcbuf_unlock_write(wb.buf)
end

"""
    next(wb)

Grab the next block of bytes we can write to
"""
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
    with_read_iter(f, client)

Create a context-managed `ReadBufferIterator` and pass it to `f`. Use this
with the `do` syntax:

```julia
with_read_iter(client) do rb
    rb.next() # ...
end
```
"""
function with_read_iter(f::Function, client::DadaClient; type=:data)
    rb = read_iter(client; type=type)
    f(rb)
    cleanup(rb)
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

"""
with_write_iter(f, client)

Create a context-managed `WriteBufferIterator` and pass it to `f`. Use this
with the `do` syntax:

```julia
with_write_iter(client) do wb
    wb.next() # ...
end
```
"""
function with_write_iter(f::Function, client::DadaClient; type=:data)
    wb = write_iter(client; type=type)
    f(wb)
    cleanup(wb)
end

# Export our API
export DadaClient,
    client_connect,
    client_create,
    read_iter,
    write_iter,
    data_size,
    data_count,
    header_size,
    header_count,
    next,
    with_write_iter,
    with_read_iter,
    cleanup,
    with_client