// 7 april 2015
#include "uipriv_darwin.h"

typedef struct singleView singleView;

struct singleView {
	NSView *view;
	NSScrollView *scrollView;
	NSView *immediate;		// the control that is added to the parent container; either view or scrollView
	uiParent *parent;
	BOOL userHid;
	BOOL containerHid;
	BOOL userDisabled;
	BOOL containerDisabled;
};

static void singleDestroy(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	[destroyedControlsView addSubview:s->immediate];
}

static uintptr_t singleHandle(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	return (uintptr_t) (s->view);
}

static void singleSetParent(uiControl *c, uiParent *parent)
{
	singleView *s = (singleView *) (c->Internal);
	NSView *parentView;
	uiParent *oldparent;

	oldparent = s->parent;
	s->parent = parent;
	if (oldparent != NULL) {
		[s->immediate removeFromSuperview];
		uiParentUpdate(oldparent);
	}
	if (s->parent != NULL) {
		// TODO uiControlView(), uiParentView()
		parentView = (NSView *) uiParentHandle(s->parent);
		[parentView addSubview:s->immediate];
		uiParentUpdate(s->parent);
	}
}

// also good for NSBox and NSProgressIndicator
static void singlePreferredSize(uiControl *c, uiSizing *d, intmax_t *width, intmax_t *height)
{
	singleView *s = (singleView *) (c->Internal);
	NSControl *control;
	NSRect r;

	control = (NSControl *) (s->view);
	[control sizeToFit];
	// use alignmentRect here instead of frame because we'll be resizing based on that
	r = [control alignmentRectForFrame:[control frame]];
	*width = (intmax_t) r.size.width;
	*height = (intmax_t) r.size.height;
}

static void singleResize(uiControl *c, intmax_t x, intmax_t y, intmax_t width, intmax_t height, uiSizing *d)
{
	singleView *s = (singleView *) (c->Internal);
	NSRect frame;

	frame.origin.x = x;
	// mac os x coordinate system has (0,0) in the lower-left
	frame.origin.y = ([[s->immediate superview] bounds].size.height - height) - y;
	frame.size.width = width;
	frame.size.height = height;
	frame = [s->immediate frameForAlignmentRect:frame];
	[s->immediate setFrame:frame];
}

static int singleVisible(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	if (s->userHid)
		return 0;
	return 1;
}

static void singleShow(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->userHid = NO;
	if (!s->containerHid) {
		[s->immediate setHidden:NO];
		if (s->parent != NULL)
			uiParentUpdate(s->parent);
	}
}

static void singleHide(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->userHid = YES;
	[s->immediate setHidden:YES];
	if (s->parent != NULL)
		uiParentUpdate(s->parent);
}

static void singleContainerShow(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->containerHid = NO;
	if (!s->userHid) {
		[s->immediate setHidden:NO];
		if (s->parent != NULL)
			uiParentUpdate(s->parent);
	}
}

static void singleContainerHide(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->containerHid = YES;
	[s->immediate setHidden:YES];
	if (s->parent != NULL)
		uiParentUpdate(s->parent);
}

static void enable(singleView *s)
{
	if ([s->view respondsToSelector:@selector(setEnabled:)])
		[((NSControl *) (s->view)) setEnabled:YES];
}

static void disable(singleView *s)
{
	if ([s->view respondsToSelector:@selector(setEnabled:)])
		[((NSControl *) (s->view)) setEnabled:NO];
}

static void singleEnable(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->userDisabled = NO;
	if (!s->containerDisabled)
		enable(s);
}

static void singleDisable(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->userDisabled = YES;
	disable(s);
}

static void singleContainerEnable(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->containerDisabled = NO;
	if (!s->userDisabled)
		enable(s);
}

static void singleContainerDisable(uiControl *c)
{
	singleView *s = (singleView *) (c->Internal);

	s->containerDisabled = YES;
	disable(s);
}

void uiDarwinNewControl(uiControl *c, Class class, BOOL inScrollView, BOOL scrollViewHasBorder)
{
	singleView *s;

	s = uiNew(singleView);
	// thanks to autoxr and arwyn in irc.freenode.net/#macdev
	s->view = (NSView *) [[class alloc] initWithFrame:NSZeroRect];
	s->immediate = s->view;

	if (inScrollView) {
		s->scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
		[s->scrollView setDocumentView:s->view];
		[s->scrollView setHasHorizontalScroller:YES];
		[s->scrollView setHasVerticalScroller:YES];
		[s->scrollView setAutohidesScrollers:YES];
		if (scrollViewHasBorder)
			[s->scrollView setBorderType:NSBezelBorder];
		else
			[s->scrollView setBorderType:NSNoBorder];
		s->immediate = (NSView *) (s->scrollView);
	}

	// and keep a reference to s->immediate for when we remove the control from its parent
	[s->immediate retain];

	c->Internal = s;
	c->Destroy = singleDestroy;
	c->Handle = singleHandle;
	c->SetParent = singleSetParent;
	c->PreferredSize = singlePreferredSize;
	c->Resize = singleResize;
	c->Visible = singleVisible;
	c->Show = singleShow;
	c->Hide = singleHide;
	c->ContainerShow = singleContainerShow;
	c->ContainerHide = singleContainerHide;
	c->Enable = singleEnable;
	c->Disable = singleDisable;
	c->ContainerEnable = singleContainerEnable;
	c->ContainerDisable = singleContainerDisable;
}

BOOL uiDarwinControlFreeWhenAppropriate(uiControl *c, NSView *newSuperview)
{
	singleView *s = (singleView *) (c->Internal);

	if (newSuperview == destroyedControlsView) {
		[s->immediate release];		// we don't need the reference anymore
		uiFree(s);
		return YES;
	}
	return NO;
}