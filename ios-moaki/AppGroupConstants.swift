import Foundation

/// 호스트 앱(이 타깃) 내부에서 공유하는 앱 그룹 식별자.
/// 키보드 확장(`MoakiKeyboard`)에도 동일한 이름의 파일이 별도로 존재한다 — 두 타깃은
/// 별도 프로세스라 소스를 공유하지 못하므로, 값이 어긋나지 않도록
/// `MoakiKeyboardTests`의 "키보드 측 값 회귀 방지 테스트"가 그쪽 값을 고정 문자열과
/// 비교해 검증한다. 이 파일을 고칠 때는 `MoakiKeyboard/Utilities/AppGroupConstants.swift`도
/// 반드시 함께 확인한다.
enum AppGroupConstants {
    static let appGroupID = "group.dev.nohkyeongho.moaki"
}
