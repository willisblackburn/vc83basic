#include "test.h"

static void set_line(const char* data, size_t length) {
    line_buffer.number = 0;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
    lp = (char)offsetof(Line, data);
}

static void test_one_op(char op, int expected00, int expected01, int expected10, int expected11) {
    char err;
    int result;
    char line_data[] = { TOKEN_NUM, 0x00, 0x00, 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    DEBUG(op);

    line_data[3] = TOKEN_OP | op;
    line_data[1] = 0;
    line_data[5] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected00);

    line_data[1] = 0;
    line_data[5] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected01);

    line_data[1] = 1;
    line_data[5] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected10);

    line_data[1] = 1;
    line_data[5] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected11);
}

static void test_one_unary_op(char op, int expected0, int expected1) {
    char err;
    int result;
    char line_data[] = { 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    DEBUG(op);

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

    test_one_op(OP_ADD, 0, 1, 1, 2);
    test_one_op(OP_SUB, 0, -1, 1, 0);

    test_one_unary_op(UNARY_OP_MINUS, 0, -1);
}

static void test_evaluate_expression_precedence(void) {
    char err;
    int result;

    // 2-1-1 = 0
    char line_data_1[] = { TOKEN_NUM, 0x02, 0x00, TOKEN_OP | OP_SUB, 
        TOKEN_NUM, 0x01, 0x00, TOKEN_OP | OP_SUB, TOKEN_NUM, 0x01, 0x00, TOKEN_NO_VALUE };
    // 2-(1-1) = 2
    char line_data_2[] = { TOKEN_NUM, 0x02, 0x00, TOKEN_OP | OP_SUB, TOKEN_PAREN,
        TOKEN_NUM, 0x01, 0x00, TOKEN_OP | OP_SUB, TOKEN_NUM, 0x01, 0x00, TOKEN_NO_VALUE, TOKEN_NO_VALUE };

    set_line(line_data_1, sizeof line_data_1);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, 0);

    set_line(line_data_2, sizeof line_data_2);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, 2);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_evaluate_expression();
    test_evaluate_expression_precedence();
    return 0;
}
