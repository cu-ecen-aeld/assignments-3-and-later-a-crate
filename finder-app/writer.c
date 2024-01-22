#include <stdio.h>
#include <errno.h>
#include <syslog.h>

void logerrno() {
	syslog(LOG_ERR, "Unexpected error: %m");
}

int main(int argc, char *argv[]) {
	if (argc < 3) {
		return 1;
	}
	openlog("a-crate-writer", LOG_ODELAY, LOG_USER);
	FILE *f = fopen(argv[1], "w+");
	if (f == NULL) {
		logerrno();
		return 1;
	} else {
		syslog(LOG_DEBUG, "Writing %s to %s", argv[2], argv[1]);
	}
	if (fprintf(f, "%s\n", argv[2]) < 0) {
		logerrno();
	}
	if (fclose(f) != 0) {
		logerrno();
	}
	return 0;
}
