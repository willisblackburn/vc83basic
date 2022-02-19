#ifndef _TEST_H

#include <assert.h>
#include <stdio.h>
#include <string.h>

#define PRINT_TEST_NAME() fprintf(stderr, "%s:\n", __func__);
#define ASSERT_OP(a, b, op) do { fprintf(stderr, "  %u  assert %s (%ld, $%lX) %s %s (%ld, $%lX): ", __LINE__, #a, (long)(a), (long)(a), #op, #b, (long)(b), (long)(b)); assert((a) op (b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_EQ(a, b) ASSERT_OP(a, b, ==)
#define ASSERT_NE(a, b) ASSERT_OP(a, b, !=)
#define ASSERT_LT(a, b) ASSERT_OP(a, b, <)
#define ASSERT_LE(a, b) ASSERT_OP(a, b, <=)
#define ASSERT_GT(a, b) ASSERT_OP(a, b, >)
#define ASSERT_GE(a, b) ASSERT_OP(a, b, >=)
#define ASSERT_STRING_EQ(a, b)  do { fprintf(stderr, "  %u  assert \"%s\" == \"%s\": ", __LINE__, (a), (b)); assert(strcmp((a), (b)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_IS_OR_IS_NOT_NULL(a, s, op) do { fprintf(stderr, "  %u  assert %s (%u, $%X) %s NULL: ", __LINE__, #a, (a), (a), s); assert((a) op NULL); fputs("OK\n", stderr); } while (0)
#define ASSERT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is", ==)
#define ASSERT_NOT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is not", !=)
#define ASSERT_OK(a) do { fprintf(stderr, "  %u  assert %s (%u, $%X, %s) is OK: ", __LINE__, #a, (a), (a), get_error_message(a)); assert(!(a)); fputs("OK\n", stderr); } while (0)

void hexdump(const char* name, const char* data, size_t length) {
    unsigned i = 0;
    fprintf(stderr, "        %s ($%04X):\n", name, data);
    for (i = 0; i < length; ++i) {
        if (i % 16 == 0) fprintf(stderr, "        %04x  ", i);
        fprintf(stderr, "%02x ", data[i]);
        if (i % 16 == 15) printf("\n");
    }
}

#define HEXDUMP(data, length) hexdump(#data, (data), (length))

// Prototypes for C wrapper functions

void memcpy_lower(char* to, const char* from, size_t size);
void memcpy_higher(char* to, const char* from, size_t size);

#endif
