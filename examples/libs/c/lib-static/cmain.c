#include <stdio.h>
#include "libmath.h"

int main() {
	int x = 5, y = 3;

	printf("add(%d, %d) = %d\n", x, y, add(x, y));
	printf("sub(%d, %d) = %d\n", x, y, sub(x, y));

	return 0;
}
