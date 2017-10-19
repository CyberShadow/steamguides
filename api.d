module steamguides.api;

import std.algorithm.iteration;
import std.array;
import std.file;
import std.net.curl;
import std.stdio;

import ae.net.ietf.url;
import ae.sys.file;
import ae.utils.regex;

import steamguides.data;
import steamguides.net;

enum urlPrefix = "http://steamcommunity.com/sharedfiles/";

string apiGet(string res)
{
	return cast(string)req(urlPrefix ~ res, HTTP.Method.get, null);
}

string apiPost(string name, string[string] params)
{
	return cast(string)req(urlPrefix ~ name, HTTP.Method.post, encodeUrlParameters(params));
}

string sessionid;

struct Guide
{
	string id;

	void removeSubsection(string sectionid)
	{
		apiPost("setguidesubsection", [
			"sessionid" : sessionid,
			"id" : this.id,
			"sectionid" : sectionid,
		]);
	}

	void addSubsection()
	{
		// apiPost("setguidesubsection", [
		// 	"sessionid" : sessionid,
		// 	"id" : this.id,
		// ]);
		writeSubsection(null, null, null);
	}

	void writeSubsection(string sectionid, string title, string description)
	{
		auto params = [
			"sessionid" : sessionid,
			"id" : this.id,
		];
		if (sectionid)
			params["sectionid"] = sectionid;
		if (title)
			params["title"] = title;
		if (description)
			params["description"] = description;

		apiPost("setguidesubsection", params);
	}

	/// Download guide data from Steam.
	/// If full == false, don't download section bodies.
	GuideData download(bool full)
	{
		assert(!full, "Not implemented");
		auto html = apiGet("manageguide/?id=" ~ this.id);
		auto sectionIDs = html
			.extractCapture(re!`href="javascript:RemoveSubSection\( subSection_\d+, '(\d+)' \)">`)
			.array;
		if (!sessionid)
		{
			sessionid = html
				.extractCapture(re!`\bg_sessionID = "([^"]*)";`)
				.front;
		}

		GuideData data;
		data.id = this.id;
		foreach (sectionID; sectionIDs)
		{
			GuideData.Section section;
			section.id = sectionID;
			data.sections ~= section;
		}
		return data;
	}
}
