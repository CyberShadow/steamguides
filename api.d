module steamguides.api;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.file;
import std.stdio;
import std.string;
import std.typecons;

import ae.net.http.common;
import ae.net.ietf.headers;
import ae.net.ietf.url;
import ae.sys.data;
import ae.sys.file;
import ae.utils.json;
import ae.utils.mime;
import ae.utils.regex;
import ae.utils.text;

import steamguides.data;
import steamguides.net;

enum urlPrefix = "https://steamcommunity.com/sharedfiles/";

string apiGet(string res)
{
	return cast(string)req(urlPrefix ~ res, "GET", null);
}

string apiPost(string name, string[string] params)
{
	return cast(string)req(urlPrefix ~ name, "POST", encodeUrlParameters(params));
}

string sessionid;

struct Guide
{
	string id;
	string imagePrefix;

	string imageAction;
	Tuple!(string, string)[] imageForm;

	void removeSubsection(string sectionid)
	{
		apiPost("removeguidesubsection", [
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

	void setSectionOrder(string[] sectionIDs)
	{
		auto params = [
			"sessionid" : sessionid,
			"id" : this.id,
		];
		foreach (n, sectionID; sectionIDs)
			params["sub_sections[" ~ sectionID ~ "][sort_order]"] = text(n);
		apiPost("setguidesubsectionorder", params);
	}

	void removePreview(string previewid)
	{
		apiPost("removepreview", [
			"sessionid" : sessionid,
			"id" : this.id,
			"previewid" : previewid,
			"ajax" : "true",
		]);
	}

	struct JsonImage
	{
		string previewid;
		int sortorder;
		string url;
		long size;
		string filename;
		int preview_type;

		GuideData.Image toGuideData(string imagePrefix)
		{
			GuideData.Image image;
			image.id = this.previewid;
			image.fileName = this.filename;
			image.fileName.skipOver(imagePrefix);
			return image;
		}
	}

	GuideData.Image[] uploadImage(string fileName, Data data)
	{
		if (data.length > 2 * 1024 * 1024)
			stderr.writefln("Warning: image file %s is over 2MB", fileName);

		string boundary = "-----------------------------" ~ randomString;
		auto postData = encodeMultipart(
			imageForm.map!(pair => MultipartPart(Headers([`Content-Disposition` : `form-data; name="` ~ pair[0] ~ `"`]), Data(pair[1]))).array ~
			MultipartPart(Headers([`Content-Disposition` : `form-data; name="file"; filename="` ~ imagePrefix ~ fileName ~ `"`, `Content-Type` : guessMime(fileName)]), data),
			boundary);
		auto html = cast(string)req(imageAction, "POST", postData.contents, ["Content-Type" : "multipart/form-data; boundary=" ~ boundary]);

		if (html.canFind("<title>Steam Community :: Error</title>"))
			throw new Exception("Steam error: " ~ html.extractCapture(re!`<h3>(.*)</h3>`).front);

		auto jsonImages = html
			.extractCapture(re!`\buploadDetails = (\[.*?\]);\n`)
			.enforceNonEmpty("Can't find uploadDetails in HTML")
			.front
			.jsonParse!(JsonImage[]);
		if (!jsonImages.length)
		{
			stderr.writeln("Image upload failed (no results), retrying with another filename");
			return uploadImage(Clock.currTime.toUnixTime.text ~ "_" ~ fileName, data);
		}
		return jsonImages.map!(image => image.toGuideData(imagePrefix)).array;
	}

	/// Download guide data from Steam.
	/// If full == false, don't download section bodies.
	GuideData download(bool full)
	{
		assert(!full, "Not implemented");
		auto html = apiGet("manageguide/?id=" ~ this.id);
		scope(failure) std.file.write("steam-error.html", html);
		if (html.canFind(`<title>Steam Community :: Error</title>`))
			throw new Exception("Steam returned error page - not logged in / cookies expired?");
		if (html.canFind(`<title>Steam Community :: Guide :: `))
			throw new Exception("Steam returned public page - not logged in / cookies expired?");
		auto sectionIDs = html
			.extractCapture(re!`href="javascript:RemoveSubSection\( subSection_\d+, '(\d+)' \)">`)
			.array;
		if (!sessionid)
		{
			sessionid = html
				.extractCapture(re!`\bg_sessionID = "([^"]*)";\n`)
				.enforceNonEmpty("Can't find g_sessionID in HTML")
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

		auto jsonImages = html
			.extractCapture(re!`\bgPreviewImages = (\[.*\]);`)
			.front
			.jsonParse!(JsonImage[]);
		foreach (jsonImage; jsonImages)
		{
			if (!jsonImage.url.length)
			{
				stderr.writeln("Detected corrupted image: ", jsonImage.filename);
				removePreview(jsonImage.previewid);
				continue;
			}
			data.images ~= jsonImage.toGuideData(imagePrefix);
		}

		auto formHtml = html
			.extractCapture(re!(`<form class="smallForm" enctype="multipart/form-data" method="POST" name="PreviewFileUpload" (.*?)</form>`, "s"))
			.front;
		this.imageAction = formHtml.extractCapture(re!`action="(.*?)"`).front;
		this.imageForm = formHtml.extractCaptures!(string, string)(re!`<input type="hidden" name="(.*?)" value="(.*?)" >`).array;

		return data;
	}
}

private R enforceNonEmpty(R)(R captures, string message)
{
	enforce(!captures.empty, message);
	return captures;
}
