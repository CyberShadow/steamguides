module steamguides.net;

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

bool verbose = true;

private static HTTP http;
static this() { http = HTTP(); }

void[] req(string url, HTTP.Method method, const(void)[] data)
{
    http.url = url;
	http.verbose = verbose;
	http.method = method;

	http.clearRequestHeaders();
	auto host = url.split("/")[2];
	auto cookiePath = buildPath(getConfigDir("cookies"), host);
	http.addRequestHeader("Cookie", cookiePath.readText.strip);

	if (data)
	{
		http.contentLength = data.length;
		http.onSend = (void[] buf)
			{
				size_t len = min(buf.length, data.length);
				buf[0..len] = data[0..len];
				data = data[len..$];
				return len;
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
    http.perform();
    enforce(statusLine.code / 100 == 2, new HTTPStatusException(statusLine.code,
            format("HTTP request returned status code %d (%s)", statusLine.code, statusLine.reason)));

    return content.data;
}
