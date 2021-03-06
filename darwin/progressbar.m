// 14 august 2015
#import "uipriv_darwin.h"

struct uiProgressBar {
	uiDarwinControl c;
	NSProgressIndicator *pi;
};

uiDarwinDefineControl(
	uiProgressBar,							// type name
	uiProgressBarType,						// type function
	pi									// handle
)

void uiProgressBarSetValue(uiProgressBar *p, int value)
{
	if (value < 0 || value > 100)
		complain("value %d out of range in progressbarSetValue()", value);
	// on 10.8 there's an animation when the progress bar increases, just like with Aero
	if (value == 100) {
		[p->pi setMaxValue:101];
		[p->pi setDoubleValue:101];
		[p->pi setDoubleValue:100];
		[p->pi setMaxValue:100];
		return;
	}
	[p->pi setDoubleValue:((double) (value + 1))];
	[p->pi setDoubleValue:((double) value)];
}

uiProgressBar *uiNewProgressBar(void)
{
	uiProgressBar *p;

	p = (uiProgressBar *) uiNewControl(uiProgressBarType());

	p->pi = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
	[p->pi setControlSize:NSRegularControlSize];
	[p->pi setBezeled:YES];
	[p->pi setStyle:NSProgressIndicatorBarStyle];
	[p->pi setIndeterminate:NO];

	uiDarwinFinishNewControl(p, uiProgressBar);

	return p;
}
