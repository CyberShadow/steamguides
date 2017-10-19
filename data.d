module steamguides.data;

struct GuideData
{
	string id;

	struct Section
	{
		string id;
		string fileName; // local only
		string title;
		string contents;
	}
	Section[] sections;

	struct Image
	{
		string id;
		string fileName;
	}
	Image[] images;
}
