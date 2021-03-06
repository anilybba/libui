// 17 august 2015
#import "uipriv_darwin.h"

// unfortunately NSMutableDictionary copies its keys, meaning we can't use it for pointers
// hence, this file
// we could expose a NSMapTable directly, but let's treat all pointers as opaque and hide the implementation, just to be safe and prevent even more rewrites later
struct mapTable {
	NSMapTable *m;
};

struct mapTable *newMap(void)
{
	struct mapTable *m;

	m = uiNew(struct mapTable);
	m->m = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
		valueOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
		capacity:0];
	return m;
}

void mapDestroy(struct mapTable *m)
{
	if ([m->m count] != 0)
		complain("attempt to destroy map with items inside; did you forget to deallocate something?");
	[m->m release];
	uiFree(m);
}

void *mapGet(struct mapTable *m, void *key)
{
	return NSMapGet(m->m, key);
}

void mapSet(struct mapTable *m, void *key, void *value)
{
	NSMapInsert(m->m, key, value);
}

void mapDelete(struct mapTable *m, void *key)
{
	NSMapRemove(m->m, key);
}
