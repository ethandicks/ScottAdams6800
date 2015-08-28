typedef struct
{
 	short Unknown;
 	short NumItems;
 	short NumActions;
 	short NumWords;		/* Smaller of verb/noun is padded to same size */
 	short NumRooms;
 	short MaxCarry;
 	short PlayerRoom;
 	short Treasures;
 	short WordLength;
 	short LightTime;
 	short NumMessages;
 	short TreasureRoom;
} Header;

typedef struct
{
	unsigned short Vocab;
	unsigned short Condition[5];
	unsigned short Action[2];
	char *Comment;
} Action;

typedef struct
{
	char *Text;
	short Exits[6];
} Room;

typedef struct
{
	char *Text;
	/* PORTABILITY WARNING: THESE TWO MUST BE 8 BIT VALUES. */
	unsigned char Location;
	unsigned char InitialLoc;
	char *AutoGet;
} Item;

typedef struct
{
	short Version;
	short AdventureNumber;
	short Unknown;
} Tail;



#define YOUARE		1	/* You are not I am */
#define SCOTTLIGHT	2	/* Authentic Scott Adams light messages */
#define DEBUGGING	4
#define PREHISTORIC_LAMP 8	/* Destroy the lamp (very old databases) */


