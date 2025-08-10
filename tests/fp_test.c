#include "test.h"

typedef struct LoadStoreTestCase {
    Float f;
    UnpackedFloat u;
} LoadStoreTestCase;

const LoadStoreTestCase load_store_test_cases[] = {
    { { 0x00000000,   0 }, { 0x00000000,   1, POSITIVE } },
    { { 0x00000000, 127 }, { 0x80000000, 127, POSITIVE } },
    { { 0x7FFFFFFE, 157 }, { 0xFFFFFFFE, 157, POSITIVE } },
    { { 0x80000000, 158 }, { 0x80000000, 158, NEGATIVE } },
    { { 0x08442211, 127 }, { 0x88442211, 127, POSITIVE } },
    // Smallest possible normalized exponent
    { { 0x00000000,   1 }, { 0x80000000,   1, POSITIVE } },
    // Subnormal
    { { 0x00000400,   0 }, { 0x00000400,   1, POSITIVE } },
};

void test_load_fp(void) {
    const LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: load_fp0(t=$%08X, e=$%02X)\n", __FILE__, __LINE__, 
                test_case->f.t, test_case->f.e);
        load_fp0(&test_case->f);
        ASSERT_FP_FIELDS_EQ(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        load_fp1(&test_case->f);
        ASSERT_FP_FIELDS_EQ(FP1, test_case->u.s, test_case->u.e, test_case->u.t);
    }
}

void test_store_fp0(void) {
    Float value;
    const LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: store_fp0(t=$%08X, e=$%02X, s=$%02X)\n", __FILE__, __LINE__,
                test_case->u.t, test_case->u.e, test_case->u.s);
        SET_FP_FIELDS(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        store_fp0(&value);
        ASSERT_FLOAT_EQ(value, test_case->f);
    }
}

void test_swap_fp0_fp1(void) {
    PRINT_TEST_NAME();
    SET_FP_FIELDS(FP0, POSITIVE, 2, 12345678L);
    SET_FP_FIELDS(FP1, NEGATIVE, 1, 1418858818L);
    swap_fp0_fp1();
    ASSERT_FP_FIELDS_EQ(FP0, NEGATIVE, 1, 1418858818L);
    ASSERT_FP_FIELDS_EQ(FP1, POSITIVE, 2, 12345678L);
}

void test_adjust_exponent(void) {
    PRINT_TEST_NAME();
    SET_FP_FIELDS(FP0, POSITIVE, 0, 0);
    adjust_exponent(0, 0);
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 0, 0);
    ASSERT_EQ(C, 0);
    adjust_exponent(1, 0);
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 1, 0);
    ASSERT_EQ(C, 0);
    adjust_exponent(0, 1);
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 0, 0);
    ASSERT_EQ(C, 0);
    SET_FP_FIELDS(FP0, POSITIVE, 192, 0);
    adjust_exponent(192, 0);
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 128, 0);
    ASSERT_EQ(C, 1);
    SET_FP_FIELDS(FP0, POSITIVE, 0, 0);
    adjust_exponent(0, 192);
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 64, 0);
    ASSERT_EQ(C, 255);
}

void call_normalize(char s, char e, unsigned long x, unsigned long t, char b,
                           char expect_e, unsigned long expect_t, int line) {
    FP0s = s;
    FP0e = e;
    FPX = x;
    FP0t = t;
    B = b;
    fprintf(stderr, "  %s:%d: normalize(t=$%08LX%08LX e=%02X s=%02X grs=%02X)\n", __FILE__, line, x, t, e, s, b);
    normalize();
    ASSERT_EQ(err, 0);
    ASSERT_FP_FIELDS_EQ(FP0, s, expect_e, expect_t);
}

void test_normalize(void) {
    PRINT_TEST_NAME();

    // 0
    call_normalize(POSITIVE, 0, 0, 0, 0, 1, 0, __LINE__);
    // 0 significand with any exponent normalizes to 0
    call_normalize(POSITIVE, 127, 0, 0, 0, 1, 0, __LINE__);
    // 1
    call_normalize(POSITIVE, 127, 0x00, 0x00000001, 0x00, 96, 0x80000000, __LINE__);
    // -1
    call_normalize(NEGATIVE, 127, 0x00, 0x00000001, 0x00, 96, 0x80000000, __LINE__);
    // 32,767
    call_normalize(POSITIVE, 157, 0x00, 0x00007FFF, 0x00, 140, 0xFFFE0000, __LINE__);
    // 2,147,483,647
    call_normalize(POSITIVE, 158, 0x00, 0x7FFFFFFF, 0x00, 157, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_normalize(NEGATIVE, 158, 0x00, 0x80000000, 0x00, 158, 0x80000000, __LINE__);
    // 2,286,166,545
    call_normalize(POSITIVE, 157, 0x00, 0x88442211, 0x00, 157, 0x88442211, __LINE__);
    // 4,294,967,296
    call_normalize(POSITIVE, 158, 0x01, 0x00000000, 0x00, 159, 0x80000000, __LINE__);
    // Subnormal
    call_normalize(POSITIVE, 9, 0x00, 0x00001234, 0x00, 1, 0x00123400, __LINE__);
    call_normalize(POSITIVE, 8, 0x00, 0x00001234, 0x00, 1, 0x00091A00, __LINE__);
}

typedef struct IntConversionTestCase {
    int int_value;
    Float float_value;
} IntConversionTestCase;

const IntConversionTestCase int_conversion_test_cases[] = {
    { 0, { 0x00000000, 0 } },
    { 1, { 0x00000000, 127 } },
    { 32767, { 0x7FFE0000, 141 } },
    { (int)-32768L, { 0x80000000, 142 } },
    { 4112, { 0x00800000, 139 } },
};

void test_int_to_fp(void) {
    const IntConversionTestCase* test_case;
    int i;
    Float result;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int_conversion_test_cases / sizeof *int_conversion_test_cases; i++) {
        test_case = int_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: int_to_fp(%d)\n", __FILE__, __LINE__, test_case->int_value);
        int_to_fp(test_case->int_value);
        store_fp0(&result);
        ASSERT_FLOAT_EQ(result, test_case->float_value);
    }
}

void test_truncate_fp_to_int(void) {
    const IntConversionTestCase* test_case;
    int i;
    int result;
    Float less_than_one = { 0x00000000, 126 };
    Float too_large = { 0x00000000, 143 };
    Float much_too_large = { 0x00000000, 196 };

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int_conversion_test_cases / sizeof *int_conversion_test_cases; i++) {
        test_case = int_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: truncate_fp_to_int32(t=$%08LX e=%02X)\n", __FILE__, __LINE__,
            test_case->float_value.t, test_case->float_value.e);
        load_fp0(&test_case->float_value);
        result = truncate_fp_to_int();
        ASSERT_EQ(err, 0);
        ASSERT_EQ(result, test_case->int_value);
    }

    // Some unusual cases.

    // If floating point value is less than 1, then output is zero.
    load_fp0(&less_than_one);
    result = truncate_fp_to_int();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 0);

    // If floating point value is >=2^16, the function should return error.
    load_fp0(&too_large);
    result = truncate_fp_to_int();
    ASSERT_NE(err, 0);
    load_fp0(&much_too_large);
    result = truncate_fp_to_int();
    ASSERT_NE(err, 0);
}

typedef struct Int32ConversionTestCase {
    unsigned long int32_value;
    Float float_value;
} Int32ConversionTestCase;

const Int32ConversionTestCase int32_conversion_test_cases[] = {
    { 0, { 0x00000000, 0 } },
    { 1, { 0x00000000, 127 } },
    { 2147483647UL, { 0x7FFFFFFE, 157 } },
    { 2147483648UL, { 0x00000000, 158 } },
    { 4294967295UL, { 0x7FFFFFFF, 158 } },
    { 4112, { 0x00800000, 139 } },
};

void test_int32_to_fp(void) {
    const Int32ConversionTestCase* test_case;
    int i;
    Float result;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int32_conversion_test_cases / sizeof *int32_conversion_test_cases; i++) {
        test_case = int32_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: int32_to_fp(%lu)\n", __FILE__, __LINE__, test_case->int32_value);
        SET_FP_FIELDS(FP0, POSITIVE, 0, test_case->int32_value);
        int32_to_fp();
        store_fp0(&result);
        ASSERT_FLOAT_EQ(result, test_case->float_value);
    }
}

void test_truncate_fp_to_int32(void) {
    const Int32ConversionTestCase* test_case;
    int i;
    unsigned long result;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int32_conversion_test_cases / sizeof *int32_conversion_test_cases; i++) {
        test_case = int32_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: truncate_fp_to_int32(t=$%08LX e=%02X)\n", __FILE__, __LINE__,
            test_case->float_value.t, test_case->float_value.e);
        load_fp0(&test_case->float_value);
        truncate_fp_to_int32();
        result = FP0t;
        ASSERT_EQ(err, 0);
        ASSERT_EQ(FP0t, test_case->int32_value);
    }
}

typedef struct OperationTestCase {
    Float arg0;
    Float arg1;
    Float result;
} OperationTestCase;

void test_operation(const char* f_name, void (*f)(const Float*), const OperationTestCase* test_cases, size_t count) {
    const OperationTestCase* test_case;
    int i;
    Float result;

    for (i = 0; i < count; i++) {
        test_case = test_cases + i;
        fprintf(stderr, "  %s:%d %s(t=%08LX e=%02X, t=%08LX e=%02X)\n", __FILE__, __LINE__, f_name,
            test_case->arg0.t, test_case->arg0.e, test_case->arg1.t, test_case->arg1.e);
        load_fp0(&test_case->arg0);
        f(&test_case->arg1);
        ASSERT_EQ(err, 0);
        store_fp0(&result);
        ASSERT_FLOAT_EQ(result, test_case->result);
    }    
}

#define TEST_OPERATION(f) \
    void test_##f(void) { \
        PRINT_TEST_NAME(); \
        test_operation(#f, f, f##_test_cases, sizeof f##_test_cases / sizeof *f##_test_cases); \
    }

const OperationTestCase fadd_test_cases[] = {
    // 0 + 0
    { { 0x00000000,   0 }, { 0x00000000,   0 }, { 0x00000000,   0 } },
    // 1 + 1
    { { 0x00000000, 127 }, { 0x00000000, 127 }, { 0x00000000, 128 } },
    // 0.5 + 0.5
    { { 0x00000000, 126 }, { 0x00000000, 126 }, { 0x00000000, 127 } },
    // -1 + (-1)
    { { 0x80000000, 127 }, { 0x80000000, 127 }, { 0x80000000, 128 } },
    // 1 + (-1)
    { { 0x00000000, 127 }, { 0x80000000, 127 }, { 0x00000000,   0 } },
    // -2 + 1
    { { 0x80000000, 128 }, { 0x00000000, 127 }, { 0x80000000, 127 } },
    // 1 + (-2)
    { { 0x00000000, 127 }, { 0x80000000, 128 }, { 0x80000000, 127 } },
    // -1 + 2
    { { 0x80000000, 127 }, { 0x00000000, 128 }, { 0x00000000, 127 } },
    // 2 + (-1)
    { { 0x00000000, 128 }, { 0x80000000, 127 }, { 0x00000000, 127 } },
    // 1 + 0.0001220703125
    { { 0x00000000, 127 }, { 0x00000000, 114 }, { 0x00040000, 127 } },
    // 1 + 3.14159
    { { 0x00000000, 127 }, { 0x490FCF81, 128 }, { 0x0487E7C1, 129 } },
    // 1 + 0.00000000046566128730
    { { 0x00000000, 127 }, { 0x00000000,  96 }, { 0x00000001, 127 } },
    // 1 + 0.00000000011641532182 (should round down)
    { { 0x00000000, 127 }, { 0x00000000,  94 }, { 0x00000000, 127 } },
    // 1 + 0.00000000023283064365 (should round up)
    { { 0x00000000, 127 }, { 0x00000000,  95 }, { 0x00000001, 127 } },
    // 1 + 0.00000000034924596547 (should round up)
    { { 0x00000000, 127 }, { 0x40000000,  95 }, { 0x00000001, 127 } },
};

TEST_OPERATION(fadd);

// fsub just delegates to fadd, so we just have to verify that the sign is changed correctly.

const OperationTestCase fsub_test_cases[] = {
    // 0 - 0
    { { 0x00000000,   0 }, { 0x00000000,   0 }, { 0x00000000,   0 } },
    // 1 - 1
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000,   0 } },
    // -1 - (-1)
    { { 0x80000000, 128 }, { 0x80000000, 128 }, { 0x00000000,   0 } },
    // 1 - (-1)
    { { 0x00000000, 128 }, { 0x80000000, 128 }, { 0x00000000, 129 } },
};

TEST_OPERATION(fsub);

const OperationTestCase fmul_test_cases[] = {
    // 0 * 0
    { { 0x00000000,   0 }, { 0x00000000,   0 }, { 0x00000000,   0 } },
    // 1 * 1
    { { 0x00000000, 127 }, { 0x00000000, 127 }, { 0x00000000, 127 } },
    // 1 * -1
    { { 0x00000000, 127 }, { 0x80000000, 127 }, { 0x80000000, 127 } },
    // -1 * 1
    { { 0x80000000, 127 }, { 0x00000000, 127 }, { 0x80000000, 127 } },
    // -1 * -1
    { { 0x80000000, 127 }, { 0x80000000, 127 }, { 0x00000000, 127 } },
    // 2 * 2
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000, 129 } },
    // 0.5 * 0.5
    { { 0x00000000, 126 }, { 0x00000000, 126 }, { 0x00000000, 125 } },
    // 10 * 10
    { { 0x20000000, 130 }, { 0x20000000, 130 }, { 0x48000000, 133 } },
    // 100 * 10
    { { 0x48000000, 133 }, { 0x20000000, 130 }, { 0x7A000000, 136 } },
    // 1000 * 10
    { { 0x7A000000, 136 }, { 0x20000000, 130 }, { 0x1C400000, 140 } },
    // 10000 * 10
    { { 0x1C400000, 140 }, { 0x20000000, 130 }, { 0x43500000, 143 } },
    // 3.14159 * 100000
    { { 0x490FCF81, 128 }, { 0x43500000, 143 }, { 0x1965E000, 145 } },
    // 2^-71 * 2^-71 (exponent -142 is out of range, adjust to -126)
    { { 0x00000000,  56 }, { 0x00000000,  56 }, { 0x00008000,   0 } },
};

TEST_OPERATION(fmul);

const OperationTestCase fdiv_test_cases[] = {
    // 1 / 1
    { { 0x00000000, 127 }, { 0x00000000, 127 }, { 0x00000000, 127 } },
    // 2 / 1
    { { 0x00000000, 128 }, { 0x00000000, 127 }, { 0x00000000, 128 } },
    // 2 / 2
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000, 127 } },
    // 100 / 10
    { { 0x48000000, 133 }, { 0x20000000, 130 }, { 0x20000000, 130 } },
    // 1000 / 10
    { { 0x7A000000, 136 }, { 0x20000000, 130 }, { 0x48000000, 133 } },
    // 10000 / 10
    { { 0x1C400000, 140 }, { 0x20000000, 130 }, { 0x7A000000, 136 } },
    // 100000 / 10
    { { 0x43500000, 143 }, { 0x20000000, 130 }, { 0x1C400000, 140 } },
    // 1 / 1.025
    { { 0x00000000, 127 }, { 0x03333333, 127 }, { 0x79C18F9C, 126 } },
    // 314159 / 100000
    { { 0x1965E000, 145 }, { 0x43500000, 143 }, { 0x490FCF81, 128 } },
};

TEST_OPERATION(fdiv);

typedef struct ComparisonTestCase {
    Float arg0;
    Float arg1;
    int result;
} ComparisonTestCase;

const ComparisonTestCase comparison_test_cases[] = {
    // TODO: fix! Exponent for subnormal cases should be 1.
    // 0 <=> 0
    { { 0x00000000,   0 }, { 0x00000000,   0 },  0 },
    // 1 <=> 0
    { { 0x00000000, 128 }, { 0x00000000,   0 },  1 },
    // 0 <=> 1
    { { 0x00000000,   0 }, { 0x00000000, 128 }, -1 },
    // 2 <=> 1
    { { 0x00000000, 129 }, { 0x00000000, 128 },  1 },
    // 1 <=> 2
    { { 0x00000000, 128 }, { 0x00000000, 129 }, -1 },
    // 1+e <=> 1
    { { 0x00000001, 128 }, { 0x00000000, 128 },  1 },
    // 1 <=> 1+e
    { { 0x00000000, 128 }, { 0x00000001, 128 }, -1 },
    // 2^126 <=> 1+e
    { { 0x00000000, 254 }, { 0x00000001, 128 },  1 },
    // 1+e <=> 2^126
    { { 0x00000001, 128 }, { 0x00000000, 254 }, -1 },
};

void test_fcmp(void) {
    const ComparisonTestCase* test_case;
    int i;
    int result;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof comparison_test_cases / sizeof *comparison_test_cases; i++) {
        test_case = comparison_test_cases + i;
        fprintf(stderr, "  %s:%d: fcmp(t=%08LX e=%02X, t=%08LX e=%02X)\n", __FILE__, __LINE__,
                test_case->arg0.t, test_case->arg0.e, test_case->arg1.t, test_case->arg1.e);
        load_fp0(&test_case->arg0);
        result = fcmp(&test_case->arg1);
        ASSERT_EQ(result, test_case->result);
    }
}

void test_char_to_digit(void) {
    char d;

    PRINT_TEST_NAME();

    d = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 0);
    d = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 9);
    char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    char_to_digit(' ');
    ASSERT_NE(err, 0);
    char_to_digit('A');
    ASSERT_NE(err, 0);
    char_to_digit(0);
    ASSERT_NE(err, 0);
    char_to_digit(255);
    ASSERT_NE(err, 0);
}

void call_fp_to_string(char s, char e, unsigned long t, const char* expect_string, int line) {
    fprintf(stderr, "  %s:%d: fp_to_string(t=$%08LX e=%02X s=%02X)\n", __FILE__, line, t, e, s);
    SET_FP_FIELDS(FP0, s, e, t);
    buffer_pos = 0;
    fp_to_string();
    buffer[buffer_pos] = '\0';
    ASSERT_STRING_EQ(buffer, expect_string);
}

void test_fp_to_string(void) {
    PRINT_TEST_NAME();

    // 0
    call_fp_to_string(POSITIVE, 0, 0x00000000, "0", __LINE__);
    // 1
    call_fp_to_string(POSITIVE, 127, 0x80000000, "1", __LINE__);
    // -1
    call_fp_to_string(NEGATIVE, 127, 0x80000000, "-1", __LINE__);
    // 10
    call_fp_to_string(POSITIVE, 130, 0xA0000000, "10", __LINE__);
    // 25
    call_fp_to_string(POSITIVE, 131, 0xC8000000, "25", __LINE__);
    // 100
    call_fp_to_string(POSITIVE, 133, 0xC8000000, "100", __LINE__);
    // -100
    call_fp_to_string(NEGATIVE, 133, 0xC8000000, "-100", __LINE__);
    // 3.14159
    call_fp_to_string(POSITIVE, 128, 0xC90FCF81, "3.14159", __LINE__);
    // 0.0314159
    call_fp_to_string(POSITIVE, 122, 0x80ADF571, "0.0314159", __LINE__);
    // 2,147,483,647
    call_fp_to_string(POSITIVE, 157, 0xFFFFFFFE, "2147483647", __LINE__);
    // -2,147,483,648
    call_fp_to_string(NEGATIVE, 158, 0x80000000, "-2147483648", __LINE__);
    // 2^36
    call_fp_to_string(POSITIVE, 163, 0x80000000, "6.87194767E10", __LINE__);
    // 2^-120
    call_fp_to_string(POSITIVE, 7, 0x80000000, "7.52316385E-37", __LINE__);
    // 1.025
    call_fp_to_string(POSITIVE, 127, 0x83333333, "1.025", __LINE__);

    // Exponent edge cases
    // +/- 1E9 should print without E
    // +/- 1E10 should print in scientific
    call_fp_to_string(POSITIVE, 156, 0xEE6B2800, "1000000000", __LINE__);
    call_fp_to_string(NEGATIVE, 156, 0xEE6B2800, "-1000000000", __LINE__);
    call_fp_to_string(POSITIVE, 160, 0x9502F900, "1E10", __LINE__);
    call_fp_to_string(NEGATIVE, 160, 0x9502F900, "-1E10", __LINE__);
}

void call_string_to_fp(const char* string, char expect_s, char expect_e, unsigned long expect_t, int line) {
    fprintf(stderr, "  %s:%d: string_to_fp(\"%s\")\n", __FILE__, line, string);
    strcpy(buffer, string);
    string_to_fp(buffer, 0);
    ASSERT_EQ(err, 0);
    ASSERT_FP_FIELDS_EQ(FP0, expect_s, expect_e, expect_t);
}

void fail_string_to_fp(const char* string, int line) {
    fprintf(stderr, "  %s:%d: string_to_fp(\"%s\")\n", __FILE__, line, string);
    strcpy(buffer, string);
    string_to_fp(buffer, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(Y, 0);
}

void test_string_to_fp(void) {
    PRINT_TEST_NAME();

    // 0
    call_string_to_fp("0", POSITIVE, 1, 0x00000000, __LINE__);
    // 1
    call_string_to_fp("1", POSITIVE, 127, 0x80000000, __LINE__);
    // -1
    call_string_to_fp("-1", NEGATIVE, 127, 0x80000000, __LINE__);
    // 10
    call_string_to_fp("10", POSITIVE, 130, 0xA0000000, __LINE__);
    // 25
    call_string_to_fp("25", POSITIVE, 131, 0xC8000000, __LINE__);
    // 100
    call_string_to_fp("100", POSITIVE, 133, 0xC8000000, __LINE__);
    // -100
    call_string_to_fp("-100", NEGATIVE, 133, 0xC8000000, __LINE__);
    // 3.14159
    call_string_to_fp("3.14159", POSITIVE, 128, 0xC90FCF81, __LINE__);
    // 0.0314159
    call_string_to_fp("0.0314159", POSITIVE, 122, 0x80ADF571, __LINE__);
    // 2,147,483,647
    call_string_to_fp("2147483647", POSITIVE, 157, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_string_to_fp("-2147483648", NEGATIVE, 158, 0x80000000, __LINE__);
    // 1.025
    call_string_to_fp("1.025", POSITIVE, 127, 0x83333333, __LINE__);

    // Verify that string_to_fp stops on non-digit.
    call_string_to_fp("10X", POSITIVE, 130, 0xA0000000, __LINE__);
    call_string_to_fp("-100-", NEGATIVE, 133, 0xC8000000, __LINE__);
    call_string_to_fp("3.14159+", POSITIVE, 128, 0xC90FCF81, __LINE__);
    
    // Verify that string_to_fp leaves buffer_pos alone when faced with non-numbers.
    fail_string_to_fp("X10", __LINE__);
    fail_string_to_fp("*3", __LINE__);
    fail_string_to_fp("-X", __LINE__);
}

int main(void) {
    initialize_target();
    test_load_fp();
    test_store_fp0();
    test_swap_fp0_fp1();
    test_adjust_exponent();
    test_normalize();
    test_int_to_fp();
    test_int32_to_fp();
    test_truncate_fp_to_int();
    test_truncate_fp_to_int32();
    test_fadd();
    test_fsub();
    test_fmul();
    test_fdiv();
    test_fcmp();
    test_char_to_digit();
    test_fp_to_string();
    test_string_to_fp();
    return 0;
}
