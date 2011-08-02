local ledge_esi_processor = {}

function ledge_esi_processor.process(ledge, response)
    -- We can't do ngx.location.capture within a Lua callback, so we must fetch
    -- in advance, and then swap afterwards.
    local tags = {response.body:match('(<esi:include.-/>)')}
    local uris = {}

    for i,tag in ipairs(tags) do
        local _, _, src = tag:find('src="(.-)"')
        
        local uri = {}
        uri.uri 		= src
        uri.key 		= 'ledge:'..ngx.md5(src) -- Hash, with .status, and .body
        uri.header_key	= uri.key..':header'	-- Hash, with header names and values
        uri.meta_key	= uri.key..':meta'		-- Meta, hash with .cacheable = true|false. Persistent.
        uri.fetch_key	= uri.key..':fetch'		-- Temp key during an origin request.
        
        uris[src] = uri
        
        -- Get from cache or origin
        local f_res = ledge.prepare(uris[src])
        if (f_res.state <= ledge.states.WARM) then
        	f_res = ledge.fetch(uris[src], f_res)
        end
        
        uris[src].response = f_res
    end
    
    -- Now actually do the replacement.
    response.body = response.body:gsub('(<esi:include.-/>)', function(tag)
        local _, _, src = tag:find('src="(.-)"')
        return uris[src].response.body
    end)
      
    response.header['X-Ledge-ESI'] = "True"
    response.header['Content-Length'] = response.body:len()
    return response
end

return ledge_esi_processor