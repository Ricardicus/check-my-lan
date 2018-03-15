#include <stdio.h>
#include <setjmp.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdlib.h>

#define START					0
#define ERROR_GIVEN_IP			1
#define ERROR_GIVEN_NETMASK		2

jmp_buf jb;

static void int_ip_to_string_ip(char * buffer, size_t size, uint32_t ip)
{
	snprintf(buffer, size, "%" PRIu32 ".%" PRIu32 ".%" PRIu32 ".%" PRIu32 "", (ip>>24), (ip>>16) & ((1<<8) - 1), (ip>>8) & ((1<<8) - 1), ip & ((1<<8) - 1));
}

// The ip should be formatted like x.x.x.x , 3 dots with digits in between
void print_ips(const char *ip, const char *netmask) 
{
	uint32_t ipn = 0, netm = 0, tmp = 0, count = 0, limit;
	int dot_count = 0; // For format checking
	char buffer[200], *c, *d;

	c = strstr(ip, "addr:");
	if ( c != NULL ) {
		snprintf(buffer, sizeof buffer, "%s", c+strlen("addr:"));
	} else {
		snprintf(buffer, sizeof buffer, "%s", ip);
	}
	// Will perform some sanity checks. There should only be 
	// digits and dots in the string. There should also be 3 dots. 

	c = buffer;

	while ( *c ) {

		if ( !isdigit(*c) ) {
			if ( *c != '.' )
				longjmp(jb, ERROR_GIVEN_IP);
			else
				dot_count++;
		}

		++c;
	}

	if ( dot_count != 3 )
		longjmp(jb, ERROR_GIVEN_IP);

	// IP is considered ok now. Will translate it into a number
	c = buffer;
	while ( c != NULL ) {
		d = strchr(c, '.');
		if ( d != NULL )
			*d = '\0';

		tmp = (uint32_t) atoi(c);
		ipn = (ipn<<8) + tmp;

		c = ( d == NULL ? d : d+1 ); 
	}

	// Now the ip is represented in the variable 'ipn'!

	// Parsing the netmask

	memset(buffer, '\0', sizeof buffer);
	c = strstr(netmask, "Mask:");
	if (c != NULL ) {
		snprintf(buffer, sizeof buffer, "%s", c + strlen("Mask:"));
        	
		int alert=0;

		c = buffer;
		while ( *c )  {
			if ( !isdigit(*c) && *c != '.')
				alert=1;
			c++;
		}

		if ( alert )
        	        longjmp(jb, ERROR_GIVEN_NETMASK);
	
		c = buffer;

	} else {
		snprintf(buffer, sizeof buffer, "%s", netmask);

        	if ( buffer[0] != '0' ||buffer[1] != 'x' )
 	               longjmp(jb, ERROR_GIVEN_NETMASK);

        	if ( strlen(buffer) != 10 )
                	longjmp(jb, ERROR_GIVEN_NETMASK);
	
		c = &buffer[2];
	}


	while ( *c ) {
		// ASCII to int conversion.. stored in tmp
		if ( *c >= 'a' && *c <= 'f' ){
			tmp = *c - 97 + 10;
	                netm = (netm<<4) + tmp;
		} else if ( isdigit(*c) ) {
			d = strchr(c,'.');
			if ( d != NULL )
				*d = '\0';

			tmp = (uint32_t) atoi(c);
			netm = (netm<<8) + tmp;
			c = c + strlen(c);
                        if ( d != NULL )
                                *d = '.';
		}
		++c;
	}

	// Now the netmask is represented in the variable 'netm'!
        /* 
	// Debugging 
	memset(buffer, '\0', sizeof buffer);
        int_ip_to_string_ip(buffer, sizeof buffer, ipn);
        printf("ip: %s\n", buffer);
	memset(buffer, '\0', sizeof buffer);
	int_ip_to_string_ip(buffer, sizeof buffer, netm);
	printf("netmask: %s\n", buffer);

	exit(0); */

	// ========== PRINTING THE IPv4 addresses of the local network! ===========
	memset(buffer, '\0', sizeof buffer);

	limit = ~netm;

	while ( count < limit ) {

		tmp = (ipn & netm) + count;
		int_ip_to_string_ip(buffer, sizeof buffer, tmp);
		printf("%s\n", buffer);

		++count;
	}

}

int main(int argc, char *argv[])
{
	int i;

	if ( argc != 3 ) {
		printf("usage: %s IPv4-address netmask\n", argv[0]);
		return -1;
	}

	switch ( setjmp(jb) ) {
	case START:
		print_ips(argv[1], argv[2]);
		break;
	case ERROR_GIVEN_IP:
		fprintf(stderr, "The given ip '%s' was not valid. Should be on the form x.x.x.x .\n", argv[1]);
		return -1;
		break;
	case ERROR_GIVEN_NETMASK:
		fprintf(stderr, "The given netmask '%s' was not valid. Should be on the form 0xXXXXXXXX or Mask:digits.digits.digits.digits .\n", argv[2]);
		return -1;
		break;		
	default:
		fprintf(stderr, "Unkown error.\n");
		return -1;
		break;
	break;
	}

	return 0;
}
