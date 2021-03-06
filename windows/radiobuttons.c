// 20 may 2015
#include "uipriv_windows.h"

// desired behavior:
// - tab moves between the radio buttons and the adjacent controls
// - arrow keys navigate between radio buttons
// - arrow keys do not leave the radio buttons (this is done in control.c)
// - arrow keys wrap around bare groups (if the previous control has WS_GROUP but the first radio button doesn't, then it doesn't; since our radio buttons are all in their own child window we can't do that)
// - clicking on a radio button draws a focus rect (TODO)

struct uiRadioButtons {
	uiWindowsControl c;
	HWND hwnd;				// of the container
	struct ptrArray *hwnds;		// of the buttons
};

static void onDestroy(uiRadioButtons *);

uiWindowsDefineControlWithOnDestroy(
	uiRadioButtons,						// type name
	uiRadioButtonsType,						// type function
	onDestroy(this);						// on destroy
)

static BOOL onWM_COMMAND(uiControl *c, HWND clicked, WORD code, LRESULT *lResult)
{
	uiRadioButtons *r = uiRadioButtons(c);
	WPARAM check;
	uintmax_t i;
	HWND hwnd;

	if (code != BN_CLICKED)
		return FALSE;
	for (i = 0; i < r->hwnds->len; i++) {
		hwnd = ptrArrayIndex(r->hwnds, HWND, i);
		check = BST_UNCHECKED;
		if (clicked == hwnd)
			check = BST_CHECKED;
		SendMessage(hwnd, BM_SETCHECK, check, 0);
	}
	*lResult = 0;
	return TRUE;
}

static void onDestroy(uiRadioButtons *r)
{
	HWND hwnd;

	while (r->hwnds->len != 0) {
		hwnd = ptrArrayIndex(r->hwnds, HWND, 0);
		ptrArrayDelete(r->hwnds, 0);
		uiWindowsUnregisterWM_COMMANDHandler(hwnd);
		uiWindowsEnsureDestroyWindow(hwnd);
	}
	ptrArrayDestroy(r->hwnds);
}

// from http://msdn.microsoft.com/en-us/library/windows/desktop/dn742486.aspx#sizingandspacing
#define radiobuttonHeight 10
// from http://msdn.microsoft.com/en-us/library/windows/desktop/bb226818%28v=vs.85%29.aspx
#define radiobuttonXFromLeftOfBoxToLeftOfLabel 12

static void minimumSize(uiWindowsControl *c, uiWindowsSizing *d, intmax_t *width, intmax_t *height)
{
	uiRadioButtons *r = uiRadioButtons(c);
	uintmax_t i;
	intmax_t wid, maxwid;

	maxwid = 0;
	for (i = 0; i < r->hwnds->len; i++) {
		wid = uiWindowsWindowTextWidth(ptrArrayIndex(r->hwnds, HWND, i));
		if (maxwid < wid)
			maxwid = wid;
	}
	*width = uiWindowsDlgUnitsToX(radiobuttonXFromLeftOfBoxToLeftOfLabel, d->BaseX) + maxwid;
	*height = uiWindowsDlgUnitsToY(radiobuttonHeight, d->BaseY) * r->hwnds->len;
}

static void radiobuttonsRelayout(uiWindowsControl *c, intmax_t x, intmax_t y, intmax_t width, intmax_t height)
{
	uiRadioButtons *r = uiRadioButtons(c);
	uiWindowsSizing *d;
	intmax_t height1;
	intmax_t h;
	uintmax_t i;
	HWND hwnd;

	uiWindowsEnsureMoveWindow(r->hwnd, x, y, width, height);

	x = 0;
	y = 0;
	d = uiWindowsNewSizing(r->hwnd);
	height1 = uiWindowsDlgUnitsToY(radiobuttonHeight, d->BaseY);
	uiWindowsFreeSizing(d);
	for (i = 0; i < r->hwnds->len; i++) {
		hwnd = ptrArrayIndex(r->hwnds, HWND, i);
		h = height1;
		if (h > height)		// clip to height
			h = height;
		uiWindowsEnsureMoveWindow(hwnd, x, y, width, h);
		y += height1;
		height -= height1;
		if (height <= 0)		// clip to height
			break;
	}
}

// TODO commit enable/disable

static void redoControlIDsZOrder(uiRadioButtons *r)
{
	HWND hwnd;
	uintmax_t i;
	LONG_PTR controlID;
	HWND insertAfter;

	controlID = 100;
	insertAfter = NULL;
	for (i = 0; i < r->hwnds->len; i++) {
		hwnd = ptrArrayIndex(r->hwnds, HWND, i);
		uiWindowsEnsureAssignControlIDZOrder(hwnd, controlID, insertAfter);
		controlID++;
		insertAfter = hwnd;
	}
}

void uiRadioButtonsAppend(uiRadioButtons *r, const char *text)
{
	HWND hwnd;
	WCHAR *wtext;
	DWORD groupTabStop;

	// the first radio button gets both WS_GROUP and WS_TABSTOP
	// successive radio buttons get *neither*
	groupTabStop = 0;
	if (r->hwnds->len == 0)
		groupTabStop = WS_GROUP | WS_TABSTOP;

	wtext = toUTF16(text);
	hwnd = uiWindowsEnsureCreateControlHWND(0,
		L"button", wtext,
		BS_RADIOBUTTON | groupTabStop,
		hInstance, NULL,
		TRUE);
	uiFree(wtext);
	uiWindowsEnsureSetParent(hwnd, r->hwnd);
	uiWindowsRegisterWM_COMMANDHandler(hwnd, onWM_COMMAND, uiControl(r));
	ptrArrayAppend(r->hwnds, hwnd);
	redoControlIDsZOrder(r);
	uiWindowsControlQueueRelayout(uiWindowsControl(r));
}

uiRadioButtons *uiNewRadioButtons(void)
{
	uiRadioButtons *r;

	r = (uiRadioButtons *) uiNewControl(uiRadioButtonsType());

	r->hwnd = newContainer();

	r->hwnds = newPtrArray();

	uiWindowsFinishNewControl(r, uiRadioButtons);
	uiWindowsControl(r)->Relayout = radiobuttonsRelayout;

	return r;
}
