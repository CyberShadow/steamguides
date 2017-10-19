module steamguides.data;

struct GuideData
{
	struct Section
	{
		string id;
		string fileName; // local only
		string title;
		string contents;
	}

	string id;
	Section[] sections;
}
