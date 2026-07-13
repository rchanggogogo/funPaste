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

var history = ClipHistory(maximumCount: 3)
history.record("第一条")
history.record("第二条")

expect(
    history.clips.map(\.content) == ["第二条", "第一条"],
    "新剪贴内容必须插入历史顶部"
)

print("通过：新内容位于历史顶部")

history.record("第一条")

expect(
    history.clips.map(\.content) == ["第一条", "第二条"],
    "相同内容再次复制时不得产生重复记录，且应回到顶部"
)

print("通过：重复内容去重并置顶")

let countBeforeSensitiveContent = history.clips.count
history.record("password: 极其私密的内容")
history.record("验证码：123456")

expect(
    history.clips.count == countBeforeSensitiveContent,
    "疑似密码和验证码不得自动记录"
)

print("通过：敏感内容自动过滤")

var limitedHistory = ClipHistory(maximumCount: 3)
["一", "二", "三", "四"].forEach { limitedHistory.record($0) }

expect(
    limitedHistory.clips.map(\.content) == ["四", "三", "二"],
    "历史记录必须遵守最大保存数量"
)

print("通过：历史数量上限")

let liveHistory = [
    Clip(id: "live", category: .recent, title: "刚复制", content: "真实剪贴内容", source: "剪贴板")
]

expect(
    Clip.presentationItems(history: liveHistory).contains { $0.category == .prompt },
    "开始记录真实历史后，Prompt 模板仍必须保留在内容库中"
)

print("通过：真实历史与 Prompt 模板共存")
