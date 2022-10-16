#include "test.h"

static void set_line(const char* data, size_t length) {
    line_buffer.number = 0;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
    lp = (char)offsetof(Line, data);
}

static void test_one_op(char op, int expected11, int expected12, int expected21) {
    char err;
    int result;
    char line_data[] = { TOKEN_NUM, 0x00, 0x00, 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    line_data[3] = TOKEN_OP | op;
    line_data[1] = 1;
    line_data[5] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected11);

    line_data[1] = 1;
    line_data[5] = 2;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected12);

    line_data[1] = 2;
    line_data[5] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected21);
}

static void test_one_unary_op(char op, int expected0, int expected1) {
    char err;
    int result;
    char line_data[] = { 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    line_data[0] = TOKEN_UNARY_OP | op;
    line_data[2] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected0);

    line_data[2] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected1);
}

static void test_evaluate_expression(void) {

    test_one_op(OP_ADD, 2, 3, 3);
    test_one_op(OP_SUB, 0, -1, 1);

    test_one_op(OP_EQ, 1, 0, 0);
    test_one_op(OP_NE, 0, 1, 1);
    test_one_op(OP_LT, 0, 1, 0);
    test_one_op(OP_LE, 1, 1, 0);
    test_one_op(OP_GT, 0, 0, 1);
    test_one_op(OP_GE, 1, 0, 1);

    test_one_unary_op(UNARY_OP_MINUS, 0, -1);
    test_one_unary_op(UNARY_OP_NOT, 1, 0);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_evaluate_expression();
    return 0;
}
