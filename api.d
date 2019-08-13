module steamguides.api;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.net.curl;
import std.stdio;
import std.typecons;

import ae.net.http.common;
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

		GuideData.Image toGuideData()
		{
			GuideData.Image image;
			image.id = this.previewid;
			image.fileName = this.filename;
			return image;
		}
	}

	GuideData.Image[] uploadImage(string fileName, Data data)
	{
		if (data.length > 2 * 1024 * 1024)
			stderr.writefln("Warning: image file %s is over 2MB", fileName);

		string boundary = "-----------------------------" ~ randomString;
		auto postData = encodeMultipart(
			imageForm.map!(pair => MultipartPart([`Content-Disposition` : `form-data; name="` ~ pair[0] ~ `"`], Data(pair[1]))).array ~
			MultipartPart([`Content-Disposition` : `form-data; name="file"; filename="` ~ fileName ~ `"`, `Content-Type` : guessMime(fileName)], data),
			boundary);
		auto html = cast(string)req(imageAction, HTTP.Method.post, postData.contents, ["Content-Type" : "multipart/form-data; boundary=" ~ boundary]);

		auto result = html
			.extractCapture(re!`\bwindow\.top\.window\.DoneFileUpload\( (".*?"), uploadDetails \);\r\n`)
			.front
			.jsonParse!string;
		switch (result)
		{
			case "1":
				break; // all OK
			case "25":
				throw new Exception("Image upload failed (file too large)");
			default:
				throw new Exception("Image upload failed (error " ~ result ~ ")");
		}

		auto jsonImages = html
			.extractCapture(re!`\buploadDetails = (\[.*?\]);\r\n`)
			.front
			.jsonParse!(JsonImage[]);
		enforce(jsonImages.length, "Image upload failed (no results)");
		return jsonImages.map!(image => image.toGuideData).array;
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
				.extractCapture(re!`\bg_sessionID = "([^"]*)";\r\n`)
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
			data.images ~= jsonImage.toGuideData;

		auto formHtml = html
			.extractCapture(re!(`<form class="smallForm" enctype="multipart/form-data" method="POST" name="PreviewFileUpload" (.*?)</form>`, "s"))
			.front;
		this.imageAction = formHtml.extractCapture(re!`action="(.*?)"`).front;
		this.imageForm = formHtml.extractCaptures!(string, string)(re!`<input type="hidden" name="(.*?)" value="(.*?)" >`).array;

		return data;
	}
}
