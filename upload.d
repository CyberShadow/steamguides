module steamguides.upload;

import ae.utils.aa;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.exception;
import std.file;
import std.stdio;
import std.string;
import std.typecons;

import steamguides.api;
import steamguides.data;

enum catalogFN = "sections.txt";

GuideData readGuide()
{
	GuideData result;
	result.id = readText("guideid.txt");

	string[string] catalog;
	if (catalogFN.exists)
		catalog = catalogFN.slurp!(string, string)("%s\t%s").map!(t => tuple(t[1], t[0])).assocArray;

	foreach (de; dirEntries("", "*.steamguide", SpanMode.shallow).array.sort())
	{
		auto lines = de.readText.splitLines;
		enforce(lines.length >= 3, "Too few lines");
		enforce(lines[1] == "", "Second line must be blank");
		GuideData.Section section;
		section.fileName = de.name;
		section.title = lines[0];
		section.contents = lines[2..$].join("\n");
		if (de.name in catalog)
			section.id = catalog[de.name];
		result.sections ~= section;
	}
	return result;
}

void main()
{
	auto localData = readGuide();

	auto api = Guide(localData.id);

	stderr.writeln("Getting guide info...");
	auto remoteData = api.download(false);
	stderr.writefln("Guide has %d sections.", remoteData.sections.length);

	auto remoteSections = remoteData.sections.map!(section => section.id).toSet;

	foreach (ref section; localData.sections)
	{
		string targetID = null;
		if (!section.id)
			stderr.writefln("Uploading new section %s...", section.fileName);
		else if (section.id in remoteSections)
		{
			stderr.writefln("Updating section %s (%s)...", section.fileName, section.id);
			targetID = section.id;
		}
		else
		{
			stderr.writefln("Recreating section %s (was ID %s)...", section.fileName, section.id);
			section.id = null;
		}

		api.writeSubsection(targetID, section.title, section.contents);

		if (!targetID)
		{
			remoteData = api.download(false);
			section.id = remoteData.sections[$-1].id;
		}
	}

	auto localSections = localData.sections.map!(section => section.id).toSet;

	foreach (section; remoteData.sections)
		if (section.id !in localSections)
		{
			stderr.writefln("Deleting extant section %s...", section.id);
			api.removeSubsection(section.id);
		}

	localData.sections.map!(section => "%s\t%s".format(section.id, section.fileName)).join("\n").toFile(catalogFN);

	stderr.writefln("Done!");
}
