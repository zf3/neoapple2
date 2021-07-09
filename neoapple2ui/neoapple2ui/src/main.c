/**
 * neoapple2ui - UI frontend for neoapple2 emulator
 * Feng Zhou, 2021-6
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "xparameters.h"	/* SDK generated parameters */
#include "xplatform_info.h"
#include "platform.h"

#include "xsdps.h"		/* SD device driver */
#include "ff.h"			/* FAT file system */
#include "xgpiops.h"
#include "sleep.h"
#include "xtime_l.h"

// EMIO GPIO example: https://www.programmersought.com/article/8774764198/

#define printf			printf	/* Smalller foot-print printf */

FATFS fs;

#define MAX_DISKS 100

// 1-based
TCHAR files[MAX_DISKS+1][FF_LFN_BUF + 1];
int numFiles = 0;

#define MAX_LINE 256
char line[MAX_LINE];

int SD_Init()
{
    FRESULT rc;

    rc = f_mount(&fs,"",0);
    if(rc)
    {
        printf("ERROR : f_mount returned %d\r\n",rc);
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

FRESULT scan_files (
    char* path        /* Start node to be scanned (also used as work area) */
)
{
    FRESULT res;
    FILINFO fno;
    DIR dir;
    char *fn;   /* This function assumes non-Unicode configuration */

    res = f_opendir(&dir, path);                       /* Open the directory */
    if (res == FR_OK) {
        for (;;) {
            res = f_readdir(&dir, &fno);                   /* Read a directory item */
            if (res != FR_OK || fno.fname[0] == 0) break;  /* Break on error or end of dir */
//            if (fno.fname[0] == '.') continue;             /* Ignore dot entry */
            fn = fno.fname;
            if (fno.fattrib & AM_DIR) {                    /* It is a directory */
//            	printf("  dir: %s\n\r", fn);
            } else {                                       /* It is a file. */
            	int len = strlen(fn);
            	if (len >= 5 && strcmp(&fn[len-4], ".nib") == 0) {
            		strcpy(files[numFiles+1], fn);
            		numFiles++;
            	} else {
                    printf("Ignoring none-nib file: %s\n\r", fn);
            	}
            }
            if (numFiles >= MAX_DISKS)
            	break;
        }
        f_closedir(&dir);
    } else {
    	printf("f_opendir return %d\n", res);
    }
    return res;
}

void print_files() {
    printf("Found %d disks images. Type a number to choose one to load:\n\r", numFiles);
    for (int i = 1; i <= numFiles; i++) {
    	printf("  %d: %s\n\r", i, files[i]);
    }
}

// Return length of input (without \n)
int get_a_line() {
	setvbuf(stdin, NULL, _IONBF, 0);
	int i = 0;
	for (; i < MAX_LINE - 1; i++) {
		char c = getchar();
		if (c != EOF && c != '\n' && c != '\r') {
			// ECHO
		    printf("%c", c);
			line[i] = c;
		} else
			break;
	}
	line[i] = '\0';
	return i;
}

XGpioPs gpio;

void gpio_init() {
	XGpioPs_Config* GpioConfigPtr;

	GpioConfigPtr = XGpioPs_LookupConfig(XPAR_PS7_GPIO_0_DEVICE_ID);
	if (GpioConfigPtr == NULL) {
		printf("Cannot find GPIO configuration. Check platform.");
		return;
	}
	XGpioPs_CfgInitialize(&gpio, GpioConfigPtr, GpioConfigPtr->BaseAddr);

	for (int p = 54; p < 64; p++) {
		 //EMIO is configured as output
		XGpioPs_SetDirectionPin(&gpio, p, 1);
	    // Enable EMIO output
		XGpioPs_SetOutputEnablePin(&gpio, p, 1);
	}
}

// 232,960 bytes
#define NIB_SIZE (35*6656)
// Delay half a cycle
#define DELAY(xx) do { \
		if (step) {    \
			getchar(); \
			printf(xx);\
		} else         \
			usleep(1);\
	} while (0)

long long timemillis() {
	XTime t;
	XTime_GetTime(&t);

	return t * 1000 / COUNTS_PER_SECOND;
}

unsigned char nib[NIB_SIZE];

void gpio_out(unsigned int w) {
	// order is important: PIN 9 is image_clk, it has to be set last
//	for (int i = 0; i <= 9; i++) {
//		XGpioPs_WritePin(&gpio, 54 + i, (w & (1 << i)) ? 1 : 0);
//	}
	XGpioPs_Write(&gpio, 2, w);
}

// Sleep in nanoseconds
//void nsleep(int nano) {
//	struct timespec t;
//	t.tv_sec = 0;
//	t.tv_nsec = nano;
//	nanosleep(&t, NULL);
//}

// if len > 0, then send only len bytes
void send_disk(int d, int step, int len) {
	// Read in data
	FIL fp;
	FRESULT r = f_open(&fp, files[d], FA_READ);
	if (r) {
		printf("Cannot open %s\n\r", files[d]);
		return;
	}
	unsigned int br;
	f_read(&fp, nib, sizeof(nib), &br);
	if (br < NIB_SIZE) {
		printf("Expecting %d bytes from nib file, got %d. Bailing...\n\r", NIB_SIZE, br);
		return;
	}
	f_close(&fp);

	// Send data through EMIO GPIO
	// Sequence: 1. image_clk (pin 9) becomes available, 2. One start cycle (image_cs == 1, pin 8), 3. Transmission of IMAGE_MAX bytes (pin 7:0), 4. End of image_clk
	long long t0 = timemillis();
	unsigned int w = 0;	// word to send
	// START CYCLE
	w = 0x300;		// image_clk=1, image_start=1
	gpio_out(w);
	DELAY("/");
	w = 0;
	gpio_out(w);	// image_clk=0, image_start=0
	DELAY("\\");

	int total = len > 0 ? len : NIB_SIZE;
	for (int i = 0; i < total; i++) {
		unsigned char d = nib[i];

		gpio_out(d);

		XGpioPs_WritePin(&gpio, 54+9, 1);  // posedge
//		w = 0x200 | d;
//		gpio_out(w);
		DELAY("[");

//		w = d;			// image_clk=0
//		gpio_out(w);
		XGpioPs_WritePin(&gpio, 54+9, 0);  // posedge
		DELAY("]");
	}

	// Stop cycle
	w = 0x200;
	gpio_out(w);
	DELAY("{");

	w = 0;
	gpio_out(w);
	DELAY("}");

	w = 0x200;
	gpio_out(w);
	DELAY("{");

	w = 0;
	gpio_out(w);
	DELAY("}");

	long long dur = timemillis() - t0;

	// We are done
	printf("Disk image sent to Apple ][ in %lld ms.\n\r", dur);

}

void help() {
	printf("Usage:\n\r");
	printf("  load <disk#>\n\r");
	printf("     Load a disk. Example: load 1\n\r");
	printf("  list\n\r");
	printf("     List all disk images.\n\r");
	printf("  step <disk#>\n\r");
	printf("     Single step sending a disk, for debug.\n\r");
	printf("  help\n\r");
	printf("     This message\n\r");
}

int main()
{
    init_platform();

    print("\n\r\n\rWelcome to ~~NeoApple2~~\n\r\n\r");
    print("Scanning SD card...\n\r");

    SD_Init();
    gpio_init(); //GPIO initialization

    scan_files("/");
    print_files();

    int step = 0, load = 0;
    for (;;) {
    	printf("> ");
    	get_a_line();
    	printf("\n\r");

		char *cmd = strtok(line, " ");
    	if (strcmp(cmd, "load") == 0) {
    		load = 1;
    	} else if (strcmp(line, "step") == 0) {
    		load = step = 1;
    	} else if (strcmp(line, "list") == 0) {
    		print_files();
    	} else {
    		help();
    	}

    	if (load) {
    		int len = NIB_SIZE;
    		char *_choice = strtok(NULL, " ");
    		char *_len = strtok(NULL, " ");
    		int choice = _choice ? atoi(_choice) : 0;
        	if (choice == 0 || choice > numFiles) {
        		print_files();
        		continue;
        	}
        	if (_len) {
        		len = atoi(_len);
        	}
    		printf("OK. Now loading image #%d of length %d bytes...\n\r", choice, len);
    		send_disk(choice, step, len);
    	}
    }

    cleanup_platform();
    return 0;
}
