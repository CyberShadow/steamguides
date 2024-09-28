module steamguides.upload;

import ae.sys.dataio;
import ae.sys.file;
import ae.sys.net.system;
import ae.utils.aa;
import ae.utils.digest;
import ae.utils.meta.args;
import ae.utils.regex;
import ae.utils.text;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.exception;
import std.file;
import std.getopt;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.typecons;

import steamguides.api;
import steamguides.data;

enum sectionMapFN = "sections.txt";
enum imageDir = "images/";
enum imageMapFN = imageDir ~ "images.txt";

GuideData readGuide()
{
	GuideData result;
	result.id = readText("guideid.txt").strip;

	GuideData.Image[string] imageMap;
	if (imageMapFN.exists)
		imageMap = imageMapFN.slurp!(string, string, string)("%s\t%s\t%s")
			.map!(t => tuple(t[2],
					args!(GuideData.Image, id => t[0], remoteHash => t[1], fileName => t[2]))).assocArray;

	if (imageDir.exists)
		foreach (de; dirEntries(imageDir, "*.{png,jpg,jpeg,gif}", SpanMode.shallow).array.sort())
		{
			GuideData.Image image;
			image.fileName = de.name.baseName;
			if (image.fileName in imageMap)
				image = imageMap[de.name.baseName];
			image.localHash = mdFile(de.name).toLowerHex.idup;
			result.images ~= image;
		}

	GuideData.Section[string] sectionMap;
	if (sectionMapFN.exists)
		sectionMap = sectionMapFN.slurp!(string, string, string)("%s\t%s\t%s")
			.map!(t => tuple(t[2],
					args!(GuideData.Section, id => t[0], remoteHash => t[1], fileName => t[2]))).assocArray;

	foreach (de; dirEntries("", "*.steamguide", SpanMode.shallow).array.sort())
	{
		auto text = de.readText;

		text = text.replaceAll!(
			(m)
			{
				auto sectionName = m[1];
				auto linkText = m[2];
				string sectionID;
				auto fileName = sectionName.endsWith(".steamguide") ? sectionName : sectionName ~ ".steamguide";
				if (fileName in sectionMap)
					sectionID = sectionMap[fileName].id;
				else
				if (fileName.exists)
					stderr.writefln(">>> No section ID yet for new section %s - please re-run a second time", fileName);
				else
				if (sectionName.match(re!`^\d{7,}$`))
					sectionID = sectionName; // assume this is a section ID
				else
					stderr.writefln(">>> Ignoring link to unknown section '%s'!", sectionName);

				return format("[url=https://steamcommunity.com/sharedfiles/filedetails/?id=%s#%s]%s[/url]",
					result.id, sectionID, linkText);
			})(re!`\[section-link=(.*?)\](.*?)\[/section-link\]`);

		text = text.replaceAll!(
			(m)
			{
				auto fileName = m[2];
				if (fileName.match(re!`^\d{6,}$`))
					return m[0]; // Numeric - leave as-is
				auto tag = "preview" ~ m[1];
				auto params = m[3];

				string imageID;
				if (fileName in imageMap)
					imageID = imageMap[fileName].id;
				else
				if ((imageDir ~ fileName).exists)
					stderr.writefln(">>> No image ID yet for new image %s - please re-run a second time", fileName);
				else
					stderr.writefln(">>> Ignoring link to unknown image '%s'!", fileName);

				return format("[%s=%s;%s][%s]", tag, imageID, params, tag);
			})(re!`\[preview(icon|img)=(.*?);(.*?)\]\[/preview(icon|img)\]`);

		auto lines = text.splitLines;
		enforce(lines.length >= 3, "Too few lines");
		enforce(lines[1] == "", "Second line must be blank");
		GuideData.Section section;
		section.fileName = de.name;
		if (section.fileName in sectionMap)
			section = sectionMap[section.fileName];
		section.title = lines[0];
		section.contents = lines[2..$].join("\n");
		section.localHash = getDigestString!MD5(text).toLower;
		result.sections ~= section;
	}

	return result;
}

void main(string[] args)
{
	import steamguides.net : verbose;
	getopt(args,
		"verbose", &verbose,
	);

	auto localData = readGuide();

	auto api = Guide(localData.id);
	if ("images/prefix.txt".exists())
		api.imagePrefix = "images/prefix.txt".readText().strip();

	stderr.writeln("Getting guide info...");
	auto remoteData = api.download(false);
	stderr.writefln("Guide has %d sections.", remoteData.sections.length);

	void save()
	{
		localData.sections.map!(section => "%s\t%s\t%s".format(section.id, section.remoteHash, section.fileName)).join("\n").atomic!writeTo(sectionMapFN);
		if (imageDir.exists)
			localData.images.map!(image => "%s\t%s\t%s".format(image.id, image.remoteHash, image.fileName)).join("\n").atomic!writeTo(imageMapFN);
	}

	auto remoteImages = remoteData.images.map!(image => image.id).toSet;
	auto remoteImageFiles = remoteData.images.map!(image => tuple(image.fileName, image.id)).assocArray;

	foreach (ref image; localData.images)
	{
		string targetID = null;
		if (!image.id)
		{
			foreach (r; remoteData.images.filter!(remoteImage => remoteImage.fileName == image.fileName))
			{
				stderr.writefln("Overwriting image %s (%s)...", r.id, r.fileName);
				api.removePreview(r.id);
				remoteImages.remove(r.id);
			}
			stderr.writefln("Uploading new image %s...", image.fileName);
		}
		else if (image.id !in remoteImages)
		{
			stderr.writefln("Recreating image %s (was ID %s)...", image.fileName, image.id);
			image.id = null;
		}
		else if (image.localHash == image.remoteHash)
		{
			stderr.writefln("Image %s (%s) is up to date, skipping.", image.fileName, image.id);
			continue;
		}
		else
		{
			stderr.writefln("Updating image %s (%s)...", image.fileName, image.id);
			targetID = image.id;
		}

		auto results = api.uploadImage(image.fileName, readData(imageDir ~ image.fileName));
		if (results.length)
		{
			enforce(results.length == 1, "Too many results");
			image.id = results[0].id;
			stderr.writefln("Uploaded new image with ID %s.", image.id);
		}
		else if (image.fileName in remoteImageFiles)
		{
			image.id = remoteImageFiles[image.fileName];
			stderr.writefln("Updated image %s by file name.", image.id);
		}
		else
		{
			enforce(image.id, "Didn't get an image ID for a new image!");
			stderr.writefln("Updated image by ID.", image.id);
		}

		image.remoteHash = image.localHash;
		save();
	}

	auto localImages = localData.images.map!(image => image.id).toSet;

	foreach (image; remoteData.images)
		if (image.id !in localImages && image.id in remoteImages)
		{
			stderr.writefln("Deleting extant image %s (%s)...", image.id, image.fileName);
			api.removePreview(image.id);
		}

	auto remoteSections = remoteData.sections.map!(section => section.id).toSet;

	foreach (ref section; localData.sections)
	{
		string targetID = null;
		if (!section.id)
			stderr.writefln("Uploading new section %s...", section.fileName);
		else if (section.id !in remoteSections)
		{
			stderr.writefln("Recreating section %s (was ID %s)...", section.fileName, section.id);
			section.id = null;
		}
		else if (section.localHash == section.remoteHash)
		{
			stderr.writefln("Section %s (%s) is up to date, skipping.", section.fileName, section.id);
			continue;
		}
		else
		{
			stderr.writefln("Updating section %s (%s)...", section.fileName, section.id);
			targetID = section.id;
		}

		api.writeSubsection(targetID, section.title, section.contents);

		if (!targetID)
		{
			remoteData = api.download(false);
			section.id = remoteData.sections[$-1].id;
		}

		section.remoteHash = section.localHash;
		save();
	}

	auto localSections = localData.sections.map!(section => section.id).toSet;

	foreach (section; remoteData.sections)
		if (section.id !in localSections)
		{
			stderr.writefln("Deleting extant section %s...", section.id);
			api.removeSubsection(section.id);
		}

	if (!equal(
			remoteData.sections.map!(section => section.id).filter!(id => id in localSections),
			localData.sections.map!(section => section.id)))
	{
		stderr.writefln("Setting section order...");
		api.setSectionOrder(localData.sections.map!(section => section.id).array);
	}

	stderr.writefln("Done!");
}
