module steamguides.upload;

import std.algorithm.sorting;
import std.array;
import std.exception;
import std.file;
import std.stdio;
import std.string;

import steamguides.api;
import steamguides.data;

GuideData readGuide()
{
	GuideData result;
	result.id = readText("guideid.txt");

	foreach (de; dirEntries("", "*.steamguide", SpanMode.shallow).array.sort())
	{
		auto lines = de.readText.splitLines;
		enforce(lines.length >= 3, "Too few lines");
		enforce(lines[1] == "", "Second line must be blank");
		GuideData.Section section;
		section.fileName = de.name;
		section.title = lines[0];
		section.contents = lines[2..$].join("\n");
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

	foreach (n, section; localData.sections)
	{
		stderr.writefln("Uploading section %d/%d...", n+1, localData.sections.length);
		api.writeSubsection(
			n < remoteData.sections.length ? remoteData.sections[n].id : null,
			section.title,
			section.contents);
	}
	if (remoteData.sections.length > localData.sections.length)
		foreach (section; remoteData.sections[localData.sections.length..$])
		{
			stderr.writefln("Deleting extraneous section %s...", section.id);
			api.removeSubsection(section.id);
		}
	stderr.writefln("Done!");
}
