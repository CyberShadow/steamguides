module steamguides.upload;

import std.algorithm.sorting;
import std.array;
import std.exception;
import std.file;
import std.stdio;
import std.string;

import steamguides.api;

struct GuideData
{
	struct Section
	{
		string title;
		string contents;
	}

	Section[] sections;
}

GuideData readGuide()
{
	GuideData result;
	foreach (de; dirEntries("", "*.steamguide", SpanMode.shallow).array.sort())
	{
		auto lines = de.readText.splitLines;
		enforce(lines.length >= 3, "Too few lines");
		enforce(lines[1] == "", "Second line must be blank");
		result.sections ~= GuideData.Section(lines[0], lines[2..$].join("\n"));
	}
	return result;
}

void main()
{
	auto guideID = readText("guideid.txt");
	auto guide = Guide(guideID);

	stderr.writeln("Getting guide info...");
	auto info = guide.getInfo();
	stderr.writefln("Guide has %d sections.", info.sections.length);
	
	auto data = readGuide();
	foreach (n, section; data.sections)
	{
		stderr.writefln("Uploading section %d/%d...", n+1, data.sections.length);
		guide.writeSubsection(
			n < info.sections.length ? info.sections[n].id : null,
			section.title,
			section.contents);
	}
	if (info.sections.length > data.sections.length)
		foreach (section; info.sections[data.sections.length..$])
		{
			stderr.writefln("Deleting extraneous section %s...", section.id);
			guide.removeSubsection(section.id);
		}
	stderr.writefln("Done!");
}
