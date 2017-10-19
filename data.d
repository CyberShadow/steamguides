module steamguides.data;

struct GuideData
{
	struct Section
	{
		string id;
		string title;
		string contents;
	}

	string id;
	Section[] sections;
}
