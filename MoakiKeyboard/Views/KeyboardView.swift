import SwiftUI

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: geometry.size.width)
            let keyHeight = KeyboardMetrics.keyHeight(for: geometry.size.height)

            ZStack {
                VStack(spacing: KeyboardMetrics.keySpacing) {
                    // Key grid (consonants or symbols based on mode)
                    KeyGridView(
                        centerKeyWidth: centerKeyWidth,
                        keyHeight: keyHeight,
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        activeKey: viewModel.activeKey,
                        // 드래그로 만들어질 모음을 미리 보여주는 건 도움이 안 된다는 판단하에
                        // 뺐다 — 방향 제스처가 진행 중(gestureDirections가 비어있지 않음)일 때는
                        // previewVowel을 안 보여주고, 천지인 스트로크 대기 중(방향 없이 대기
                        // 모음만 있는 경우)에는 그대로 보여준다.
                        previewVowel: viewModel.gestureDirections.isEmpty ? viewModel.previewVowel : nil,
                        onConsonantTap: { consonant in
                            viewModel.inputConsonant(consonant)
                        },
                        onSymbolTap: { symbol in
                            viewModel.inputSymbol(symbol)
                        },
                        onBackspacePressStart: {
                            viewModel.beginBackspacePress()
                        },
                        onBackspacePressEnd: {
                            viewModel.endBackspacePress()
                        },
                        onLongPressNumber: { number in
                            viewModel.inputLongPressNumber(number)
                        },
                        onGestureStart: { row, column, point in
                            viewModel.gestureStarted(row: row, column: column, at: point)
                        },
                        onGestureMove: { point in
                            viewModel.gestureMoved(to: point)
                        },
                        onGestureEnd: { row, column in
                            viewModel.gestureEnded(row: row, column: column)
                        },
                        onRequestAccessibilityVowelPicker: { consonant in
                            viewModel.showAccessibilityVowelPicker(for: consonant)
                        }
                    )

                    // Function row
                    FunctionRowView(
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        onToggleModePressed: {
                            viewModel.toggleMode()
                        },
                        onSwitchKeyboardPressed: {
                            viewModel.switchToNextKeyboard()
                        },
                        onSnippetsPressed: {
                            viewModel.showSnippetCandidates()
                        },
                        onHanjaPressed: {
                            viewModel.showHanjaCandidates()
                        },
                        onSpaceDragStart: { point in
                            viewModel.beginSpacePress(at: point)
                        },
                        onSpaceDragMove: { point in
                            viewModel.spacePressMoved(to: point)
                        },
                        onSpaceDragEnd: {
                            viewModel.endSpacePress()
                        },
                        onPunctuationPressed: {
                            viewModel.inputPunctuationCluster()
                        },
                        onReturnPressed: {
                            viewModel.inputReturn()
                        }
                    )
                }
                .padding(KeyboardMetrics.keySpacing)

                // 드래그 방향 화살표 + 예상 모음을 띄우는 건 실사용에 도움이 안 된다는
                // 판단하에 제거했다 — 실제로 입력됐는지는 텍스트 필드에서 확인하면 충분하고,
                // 드래그 자체가 인식되고 있다는 건 햅틱(gestureMoved 참고)과 키 눌림
                // 배경색 변화로만 알려준다. 천지인 스트로크 대기 모음 미리보기(방향 없이
                // previewVowel만 있는 경우)는 여러 탭을 조합하는 동안 꼭 필요해서 유지한다.
                let isCheonjiinPreview = viewModel.gestureDirections.isEmpty && viewModel.previewVowel != nil
                if isCheonjiinPreview && !viewModel.isSymbolMode {
                    GestureOverlayView(
                        startPoint: viewModel.gestureStartPoint,
                        pendingVowel: viewModel.previewVowel
                    )
                }

                // 한자 후보 바 (커서 앞 음절에 대응하는 한자가 있을 때만 상단에 표시)
                if !viewModel.hanjaCandidates.isEmpty {
                    VStack(spacing: 0) {
                        HanjaCandidateBar(
                            candidates: viewModel.hanjaCandidates,
                            onSelect: { candidate in
                                viewModel.selectHanjaCandidate(candidate)
                            }
                        )
                        Spacer()
                    }
                }

                // 문구 후보 바 ("문구" 버튼을 탭했을 때 등록해둔 문구가 있으면 상단에 표시)
                if !viewModel.snippetCandidates.isEmpty {
                    VStack(spacing: 0) {
                        SnippetCandidateBar(
                            snippets: viewModel.snippetCandidates,
                            onSelect: { snippet in
                                viewModel.selectSnippetCandidate(snippet)
                            }
                        )
                        Spacer()
                    }
                }

                // VoiceOver 접근성 모음 선택 바 (자음 키의 커스텀 액션으로 진입)
                if let consonant = viewModel.accessibilityVowelPickerConsonant {
                    VStack(spacing: 0) {
                        AccessibilityVowelPickerBar(
                            consonant: consonant,
                            onSelect: { vowel in
                                viewModel.selectAccessibilityVowel(vowel)
                            },
                            onCancel: {
                                viewModel.dismissAccessibilityVowelPicker()
                            }
                        )
                        Spacer()
                    }
                }
            }
            .background(Color(.systemGray6))
        }
    }
}

#Preview {
    KeyboardView(viewModel: KeyboardViewModel())
        .frame(height: 280)
}
