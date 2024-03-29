#include <string.h>
#include <errno.h>
#include <sys/resource.h>
#include "test.h"

int t_memfill()
{
	int r = 0;
	if (t_vmfill(0,0,0) < 0) {
		t_error("vmfill failed: %s\n", strerror(errno));
		r = -1;
	}
	if (t_setrlim(RLIMIT_DATA, 0) < 0)
		r = -1;
	return r;
}
