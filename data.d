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
		string oldHash, currentHash; // local only
	}
	Section[] sections;

	struct Image
	{
		string id;
		string fileName;
		string oldHash, currentHash; // local only
	}
	Image[] images;
}
