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
		string remoteHash, localHash; // local only
	}
	Section[] sections;

	struct Image
	{
		string id;
		string fileName;
		string remoteHash, localHash; // local only
	}
	Image[] images;
}
