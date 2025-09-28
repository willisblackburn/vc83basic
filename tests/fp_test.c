#include "test.h"

typedef struct LoadStoreTestCase {
    Float f;
    UnpackedFloat u;
} LoadStoreTestCase;

const LoadStoreTestCase load_store_test_cases[] = {
    { { 0x00000000,   0 }, { 0x00000000,   0, POSITIVE } },
    { { 0x00000000, 128 }, { 0x80000000, 128, POSITIVE } },
    { { 0x7FFFFFFE, 158 }, { 0xFFFFFFFE, 158, POSITIVE } },
    { { 0x80000000, 159 }, { 0x80000000, 159, NEGATIVE } },
    { { 0x08442211, 128 }, { 0x88442211, 128, POSITIVE } },
    // Smallest possible normalized exponent
    { { 0x00000000,   1 }, { 0x80000000,   1, POSITIVE } },
};

void test_load_fp(void) {
    const LoadStoreTestCase* test_case;
    int i;
    Float malformed_zero = { 0x00000400, 0 };

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: load_fp0(t=$%08LX e=$%02X)\n", __FILE__, __LINE__, 
                test_case->f.t, test_case->f.e);
        load_fp0(&test_case->f);
        ASSERT_FP_FIELDS_EQ(FP0, test_case->u.s, test_case->u.e, test_case->u.t);
        load_fp1(&test_case->f);
        ASSERT_FP_FIELDS_EQ(FP1, test_case->u.s, test_case->u.e, test_case->u.t);
    }

    // Verify that the entire significand field is cleared if the exponent is 0.
    load_fp0(&malformed_zero);
    ASSERT_FP_FIELDS_EQ(FP0, 0, 0, 0);
}

void test_store_fp0(void) {
    Float value;
    const LoadStoreTestCase* test_case;
    int i;

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof load_store_test_cases / sizeof *load_store_test_cases; i++) {
        test_case = load_store_test_cases + i;
        fprintf(stderr, "  %s:%d: store_fp0(t=$%08LX e=$%02X s=$%02X)\n", __FILE__, __LINE__,
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
    SET_FP_FIELDS(FP0, s, e, t);
    FPX = x;
    B = b;
    C = 0; // high byte of exponent
    fprintf(stderr, "  %s:%d: normalize(t=$%08LX%08LX e=%02X s=%02X grs=%02X)\n", __FILE__, line, x, t, e, s, b);
    normalize();
    ASSERT_EQ(err, 0);
    ASSERT_FP_FIELDS_EQ(FP0, s, expect_e, expect_t);
}

void test_normalize(void) {
    PRINT_TEST_NAME();

    // 0
    call_normalize(POSITIVE, 0, 0, 0, 0, 0, 0, __LINE__);
    // 0 significand with any exponent normalizes to 0
    call_normalize(POSITIVE, 128, 0, 0, 0, 0, 0, __LINE__);
    // 1
    call_normalize(POSITIVE, 128, 0x00, 0x00000001, 0x00, 97, 0x80000000, __LINE__);
    // -1
    call_normalize(NEGATIVE, 128, 0x00, 0x00000001, 0x00, 97, 0x80000000, __LINE__);
    // 32,767
    call_normalize(POSITIVE, 158, 0x00, 0x00007FFF, 0x00, 141, 0xFFFE0000, __LINE__);
    // 2,147,483,647
    call_normalize(POSITIVE, 159, 0x00, 0x7FFFFFFF, 0x00, 158, 0xFFFFFFFE, __LINE__);
    // -2,147,483,648
    call_normalize(NEGATIVE, 159, 0x00, 0x80000000, 0x00, 159, 0x80000000, __LINE__);
    // 2,286,166,545
    call_normalize(POSITIVE, 158, 0x00, 0x88442211, 0x00, 158, 0x88442211, __LINE__);
    // 4,294,967,296
    call_normalize(POSITIVE, 159, 0x01, 0x00000000, 0x00, 160, 0x80000000, __LINE__);

    // If e is already 0 then should fail.
    SET_FP_FIELDS(FP0, 0x00, 0, 0x80818283);
    FPX = 0;
    B = 0;
    C = 0;
    normalize();
    ASSERT_NE(err, 0);

    // If e is >0 but reaches 0 before we finish normalizing, also fail.
    SET_FP_FIELDS(FP0, 0x00, 5, 0x00008283);
    FPX = 0;
    B = 0;
    C = 0;
    normalize();
    ASSERT_NE(err, 0);
}

typedef struct IntConversionTestCase {
    int int_value;
    Float float_value;
} IntConversionTestCase;

const IntConversionTestCase int_conversion_test_cases[] = {
    { 0, { 0x00000000, 0 } },
    { 1, { 0x00000000, 128 } },
    { 32767, { 0x7FFE0000, 142 } },
    { (int)-32768L, { 0x80000000, 143 } },
    { 4112, { 0x00800000, 140 } },
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
    Float less_than_one = { 0x00000000, 127 };
    Float too_large = { 0x00000000, 144 };
    Float much_too_large = { 0x00000000, 197 };

    PRINT_TEST_NAME();

    for (i = 0; i < sizeof int_conversion_test_cases / sizeof *int_conversion_test_cases; i++) {
        test_case = int_conversion_test_cases + i;
        fprintf(stderr, "  %s:%d: truncate_fp_to_int(t=$%08LX e=%02X)\n", __FILE__, __LINE__,
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
    { 1, { 0x00000000, 128 } },
    { 2147483647UL, { 0x7FFFFFFE, 158 } },
    { 2147483648UL, { 0x00000000, 159 } },
    { 4294967295UL, { 0x7FFFFFFF, 159 } },
    { 4112, { 0x00800000, 140 } },
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
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000, 129 } },
    // 0.5 + 0.5
    { { 0x00000000, 127 }, { 0x00000000, 127 }, { 0x00000000, 128 } },
    // -1 + (-1)
    { { 0x80000000, 128 }, { 0x80000000, 128 }, { 0x80000000, 129 } },
    // 1 + (-1)
    { { 0x00000000, 128 }, { 0x80000000, 128 }, { 0x00000000,   0 } },
    // -2 + 1
    { { 0x80000000, 129 }, { 0x00000000, 128 }, { 0x80000000, 128 } },
    // 1 + (-2)
    { { 0x00000000, 128 }, { 0x80000000, 129 }, { 0x80000000, 128 } },
    // -1 + 2
    { { 0x80000000, 128 }, { 0x00000000, 129 }, { 0x00000000, 128 } },
    // 2 + (-1)
    { { 0x00000000, 129 }, { 0x80000000, 128 }, { 0x00000000, 128 } },
    // 1 + 0.0001220703125
    { { 0x00000000, 128 }, { 0x00000000, 115 }, { 0x00040000, 128 } },
    // 1 + 3.14159
    { { 0x00000000, 128 }, { 0x490FCF81, 129 }, { 0x0487E7C1, 130 } },
    // 1 + 0.00000000046566128730
    { { 0x00000000, 128 }, { 0x00000000,  97 }, { 0x00000001, 128 } },
    // 1 + 0.00000000011641532182 (should round down)
    { { 0x00000000, 128 }, { 0x00000000,  95 }, { 0x00000000, 128 } },
    // 1 + 0.00000000023283064365 (should round up)
    { { 0x00000000, 128 }, { 0x00000000,  96 }, { 0x00000001, 128 } },
    // 1 + 0.00000000034924596547 (should round up)
    { { 0x00000000, 128 }, { 0x40000000,  96 }, { 0x00000001, 128 } },
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
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000, 128 } },
    // 1 * -1
    { { 0x00000000, 128 }, { 0x80000000, 128 }, { 0x80000000, 128 } },
    // -1 * 1
    { { 0x80000000, 128 }, { 0x00000000, 128 }, { 0x80000000, 128 } },
    // -1 * -1
    { { 0x80000000, 128 }, { 0x80000000, 128 }, { 0x00000000, 128 } },
    // 2 * 2
    { { 0x00000000, 129 }, { 0x00000000, 129 }, { 0x00000000, 130 } },
    // 0.5 * 0.5
    { { 0x00000000, 127 }, { 0x00000000, 127 }, { 0x00000000, 126 } },
    // 10 * 10
    { { 0x20000000, 131 }, { 0x20000000, 131 }, { 0x48000000, 134 } },
    // 100 * 10
    { { 0x48000000, 134 }, { 0x20000000, 131 }, { 0x7A000000, 137 } },
    // 1000 * 10
    { { 0x7A000000, 137 }, { 0x20000000, 131 }, { 0x1C400000, 141 } },
    // 10000 * 10
    { { 0x1C400000, 141 }, { 0x20000000, 131 }, { 0x43500000, 144 } },
    // 3.14159 * 100000
    { { 0x490FCF81, 129 }, { 0x43500000, 144 }, { 0x1965E000, 146 } },
};

TEST_OPERATION(fmul);

const OperationTestCase fdiv_test_cases[] = {
    // 1 / 1
    { { 0x00000000, 128 }, { 0x00000000, 128 }, { 0x00000000, 128 } },
    // 2 / 1
    { { 0x00000000, 129 }, { 0x00000000, 128 }, { 0x00000000, 129 } },
    // 2 / 2
    { { 0x00000000, 129 }, { 0x00000000, 129 }, { 0x00000000, 128 } },
    // 100 / 10
    { { 0x48000000, 134 }, { 0x20000000, 131 }, { 0x20000000, 131 } },
    // 1000 / 10
    { { 0x7A000000, 137 }, { 0x20000000, 131 }, { 0x48000000, 134 } },
    // 10000 / 10
    { { 0x1C400000, 141 }, { 0x20000000, 131 }, { 0x7A000000, 137 } },
    // 100000 / 10
    { { 0x43500000, 144 }, { 0x20000000, 131 }, { 0x1C400000, 141 } },
    // 1 / 1.025
    { { 0x00000000, 128 }, { 0x03333333, 128 }, { 0x79C18F9C, 127 } },
    // 314159 / 100000
    { { 0x1965E000, 146 }, { 0x43500000, 144 }, { 0x490FCF81, 129 } },
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

void call_fp_to_string(unsigned long t, char e, const char* expect_string, int line) {
    Float value;
    value.t = t;
    value.e = e;
    fprintf(stderr, "  %s:%d: fp_to_string(t=$%08LX e=%02X)\n", __FILE__, line, t, e);
    load_fp0(&value);
    buffer_pos = 0;
    fp_to_string();
    buffer[buffer_pos] = '\0';
    ASSERT_STRING_EQ(buffer, expect_string);
}

void test_fp_to_string(void) {
    PRINT_TEST_NAME();

    // 0
    call_fp_to_string(0x00000000, 0, "0", __LINE__);
    // 1
    call_fp_to_string(0x00000000, 128, "1", __LINE__);
    // -1
    call_fp_to_string(0x80000000, 128, "-1", __LINE__);
    // 10
    call_fp_to_string(0x20000000, 131, "10", __LINE__);
    // 25
    call_fp_to_string(0x48000000, 132, "25", __LINE__);
    // 100
    call_fp_to_string(0x48000000, 134, "100", __LINE__);
    // -100
    call_fp_to_string(0xC8000000, 134, "-100", __LINE__);
    // 3.14159
    call_fp_to_string(0x490FCF81, 129, "3.14159", __LINE__);
    // 0.0314159
    call_fp_to_string(0x00ADF571, 123, "0.0314159", __LINE__);
    // 2,147,483,647
    call_fp_to_string(0x7FFFFFFE, 158, "2147483647", __LINE__);
    // -2,147,483,648
    call_fp_to_string(0x80000000, 159, "-2147483648", __LINE__);
    // 2^36
    call_fp_to_string(0x00000000, 164, "6.87194767E10", __LINE__);
    // 2^-120
    call_fp_to_string(0x00000000, 8, "7.52316385E-37", __LINE__);
    // 1.025
    call_fp_to_string(0x03333333, 128, "1.025", __LINE__);

    // Exponent edge cases
    // +/- 1E9 should print without E
    // +/- 1E10 should print in scientific
    call_fp_to_string(0x6E6B2800, 157, "1000000000", __LINE__);
    call_fp_to_string(0xEE6B2800, 157, "-1000000000", __LINE__);
    call_fp_to_string(0x1502F900, 161, "1E10", __LINE__);
    call_fp_to_string(0x9502F900, 161, "-1E10", __LINE__);
}

void call_string_to_fp(const char* string, unsigned long expect_t, char expect_e, int line) {
    Float expect_result;
    Float result;
    expect_result.t = expect_t;
    expect_result.e = expect_e;
    fprintf(stderr, "  %s:%d: string_to_fp(\"%s\")\n", __FILE__, line, string);
    strcpy(buffer, string);
    string_to_fp(buffer, 0);
    store_fp0(&result);
    ASSERT_EQ(err, 0);
    ASSERT_FLOAT_EQ(result, expect_result);
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
    call_string_to_fp("0", 0x00000000, 0, __LINE__);
    // 1
    call_string_to_fp("1", 0x00000000, 128, __LINE__);
    // -1
    call_string_to_fp("-1", 0x80000000, 128, __LINE__);
    // 10
    call_string_to_fp("10", 0x20000000, 131, __LINE__);
    // 25
    call_string_to_fp("25", 0x48000000, 132, __LINE__);
    // 100
    call_string_to_fp("100", 0x48000000, 134, __LINE__);
    // -100
    call_string_to_fp("-100", 0xC8000000, 134, __LINE__);
    // 3.14159
    call_string_to_fp("3.14159", 0x490FCF81, 129, __LINE__);
    // 0.0314159
    call_string_to_fp("0.0314159", 0x00ADF571, 123, __LINE__);
    // 2,147,483,647
    call_string_to_fp("2147483647", 0x7FFFFFFE, 158, __LINE__);
    // -2,147,483,648
    call_string_to_fp("-2147483648", 0x80000000, 159, __LINE__);
    // 1.025
    call_string_to_fp("1.025", 0x03333333, 128, __LINE__);

    // Verify that string_to_fp stops on non-digit.
    call_string_to_fp("10X", 0x20000000, 131, __LINE__);
    call_string_to_fp("-100-", 0xC8000000, 134, __LINE__);
    call_string_to_fp("3.14159+", 0x490FCF81, 129, __LINE__);
    
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
