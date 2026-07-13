import FunPasteUI

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("测试失败：\(message)")
    }
}

expect(
    Array(ClipCategory.defaultOrder.prefix(2)) == [.recent, .prompt],
    "默认分类必须先展示最近复制，再展示 Prompt"
)

print("通过：默认分类顺序")

expect(
    Clip.demo.first { $0.category == .prompt }?.content.contains("{{功能描述}}") == true,
    "内置开发 Prompt 必须保留功能描述变量"
)

print("通过：Prompt 变量")

expect(
    FunPasteTheme.accentHex == "#FF9F5B",
    "丝带卡组必须使用暖柑橘色作为焦点强调色"
)

print("通过：界面强调色")
