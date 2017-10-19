module steamguides.net;

import etc.c.curl : CurlSeek, CurlSeekPos;

import std.algorithm.comparison;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.net.curl;
import std.path;
import std.stdio : stderr;
import std.string;

import ae.sys.file;
import ae.sys.paths;

bool verbose = false;

private static HTTP http;
static this() { http = HTTP(); }

void[] req(string url, HTTP.Method method, const(void)[] data, string[string] extraHeaders = null)
{
    http.url = url;
	http.verbose = verbose;
	http.method = method;

	http.clearRequestHeaders();
	auto host = url.split("/")[2];
	auto cookiePath = buildPath(getConfigDir("cookies"), host);
	if (cookiePath.exists)
		http.addRequestHeader("Cookie", cookiePath.readText.strip);
	else
		stderr.writeln("No cookies file: ", cookiePath);
	foreach (name, value; extraHeaders)
		http.addRequestHeader(name, value);
	http.maxRedirects = uint.max;

	if (data)
	{
		http.contentLength = data.length;
		auto remainingData = data;
		http.onSend =
			(void[] buf)
			{
				size_t len = min(buf.length, remainingData.length);
				buf[0..len] = remainingData[0..len];
				remainingData = remainingData[len..$];
				return len;
			};
        http.handle.onSeek =
	        (long offset, CurlSeekPos mode)
	        {
		        switch (mode)
		        {
			        case CurlSeekPos.set:
			        	remainingData = data[cast(size_t) offset..$];
			        	return CurlSeek.ok;
			        default:
			        	return CurlSeek.cantseek;
		        }
	        };
	}
	else
		http.onSend = null;

    import std.algorithm.comparison : min;
    import std.format : format;

    HTTP.StatusLine statusLine;
    import std.array : appender;
    auto content = appender!(ubyte[])();
    http.onReceive = (ubyte[] data)
    {
        content ~= data;
        return data.length;
    };

    http.onReceiveStatusLine = (HTTP.StatusLine l) { statusLine = l; };
    string[string] responseHeaders;
    http.onReceiveHeader = (in char[] key, in char[] value) { responseHeaders[key.idup] = value.idup; };
    http.perform();
    if (statusLine.code / 100 == 3)
    {
	    stderr.writeln("Following redirect!");
	    return req(responseHeaders["location"], HTTP.Method.get, null, null);
    }
    enforce(statusLine.code / 100 == 2, new HTTPStatusException(statusLine.code,
            format("HTTP request returned status code %d (%s)", statusLine.code, statusLine.reason)));

    return content.data;
}
