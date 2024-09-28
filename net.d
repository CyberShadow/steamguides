module steamguides.net;

import std.algorithm.comparison;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.stdio : stderr;
import std.string;

import ae.net.http.common;
import ae.sys.data : Data;
import ae.sys.dataset;
import ae.sys.file;
import ae.sys.net.system;
import ae.sys.net;
import ae.sys.paths;
import ae.utils.array;

bool verbose = false;

void[] req(string url, string method, const(void)[] data, string[string] extraHeaders = null)
{
    auto request = new HttpRequest(url);
    request.method = method;
    // request.verbose = verbose;

	auto host = url.split("/")[2];
	auto cookiePath = buildPath(getConfigDir("cookies"), host);
	if (cookiePath.exists)
		request.headers["Cookie"] = cookiePath.readText.strip;
	else
		stderr.writeln("No cookies file: ", cookiePath);
    foreach (name, value; extraHeaders)
        request.headers[name] = value;
	// http.maxRedirects = uint.max; // TODO

	if (data)
        request.data = DataVec(Data(data.asBytes));

    auto response = net.httpRequest(request);
    if (response.status / 100 == 3)
    {
	    auto target = response.headers["location"];
	    stderr.writeln("Following redirect to " ~ target);
		return req(target, "GET", null, null);
    }
    enforce(response.status / 100 == 2, new Exception(format(
        "HTTP request returned status code %d (%s)",
        response.status, response.statusMessage
    )));

    return response.data.joinToGC;
}
