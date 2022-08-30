using PSRDADA_jll

mutable struct ipcsync_t
    semkey_connect::Cint
    semkey_data::NTuple{8,Cint}
    nbufs::UInt64
    bufsz::UInt64
    w_buf_next::UInt64
    w_buf_curr::UInt64
    w_state::Cint
    w_xfer::UInt64
    r_bufs::NTuple{8,UInt64}
    r_states::NTuple{8,Cint}
    r_xfers::NTuple{8,UInt64}
    n_readers::Cuint
    s_buf::NTuple{8,UInt64}
    s_byte::NTuple{8,UInt64}
    eod::NTuple{8,UInt8}
    e_buf::NTuple{8,UInt64}
    e_byte::NTuple{8,UInt64}
    on_device_id::Cint
end

mutable struct ipcbuf_t
    state::Cint
    syncid::Cint
    semid_connect::Cint
    semid_data::Ptr{Cint}
    shmid::Ptr{Cint}
    sync::Ptr{ipcsync_t}
    buffer::Ptr{Ptr{UInt8}}
    shm_addr::Ptr{Ptr{Cvoid}}
    count::Ptr{UInt8}
    shmkey::Ptr{Cint}
    viewbuf::UInt64
    xfer::UInt64
    soclock_buf::UInt64
    iread::Cint
end

ipcbuf_t() = ipcbuf_t(0, -1, -1, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, 0, 0, 0, -1)

function ipcbuf_create(key::Integer, nbufs::Integer, bufsz::Integer)
    # Pass a Ref to ccall because Julia's GC is managing the ipcbuf memory
    buf = Ref{ipcbuf_t}(ipcbuf_t())
    ret = ccall((:ipcbuf_create, libpsrdada), Cint, (Ref{ipcbuf_t}, Cint, UInt64, UInt64, Cuint), buf, key, nbufs, bufsz, 1)
    @assert ret >= 0 "ipcbuf_create failed"
    return buf
end

function ipcbuf_connect(key::Integer)
    buf = Ref{ipcbuf_t}(ipcbuf_t())
    ret = ccall((:ipcbuf_connect, libpsrdada), Cint, (Ref{ipcbuf_t}, Cint), buf, key)
    @assert ret >= 0 "ipcbuf_connect failed"
    return buf
end

function ipcbuf_mark_filled(buf::Ref{ipcbuf_t}, bytes_written::Integer)
    ret = ccall((:ipcbuf_mark_filled, libpsrdada), Cint, (Ref{ipcbuf_t}, UInt64), buf, bytes_written)
    @assert ret >= 0 "ipcbuf_mark_filled failed"
end

function ipcbuf_get_next_read(buf::Ref{ipcbuf_t})
    sz = Ref{UInt64}(0)
    ptr = ccall((:ipcbuf_get_next_read, libpsrdada), Ptr{UInt8}, (Ref{ipcbuf_t}, Ref{UInt64}), buf, sz)
    @assert ptr != C_NULL "ipcbuf_get_next_read returned null"
    unsafe_wrap(Array, ptr, sz[])
end

function ipcbuf_get_next_write(buf::Ref{ipcbuf_t})
    ptr = ccall((:ipcbuf_get_next_write, libpsrdada), Ptr{UInt8}, (Ref{ipcbuf_t},), buf)
    @assert ptr != C_NULL "ipcbuf_get_next_write returned null"
    unsafe_wrap(Array, ptr, ipcbuf_get_bufsz(buf))
end

function ipcbuf_eod(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_eod, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    ret == 1
end

function ipcbuf_get_bufsz(buf::Ref{ipcbuf_t})
    ccall((:ipcbuf_get_bufsz, libpsrdada), UInt64, (Ref{ipcbuf_t},), buf)
end

function ipcbuf_get_nbufs(buf::Ref{ipcbuf_t})
    ccall((:ipcbuf_get_nbufs, libpsrdada), UInt64, (Ref{ipcbuf_t},), buf)
end

function ipcbuf_mark_cleared(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_mark_cleared, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_mark_cleared failed"
end

function ipcbuf_enable_eod(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_enable_eod, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_enable_eod failed"
end

function ipcbuf_destroy(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_destroy, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_destroy failed"
end

function ipcbuf_reset(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_reset, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_reset failed"
end

function ipcbuf_lock_write(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_lock_write, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_lock_write failed"
end

function ipcbuf_unlock_write(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_unlock_write, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_unlock_write failed"
end

function ipcbuf_lock_read(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_lock_read, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_lock_read failed"
end

function ipcbuf_unlock_read(buf::Ref{ipcbuf_t})
    ret = ccall((:ipcbuf_unlock_read, libpsrdada), Cint, (Ref{ipcbuf_t},), buf)
    @assert ret >= 0 "ipcbuf_unlock_read failed"
end