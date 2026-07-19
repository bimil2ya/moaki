import SwiftUI

/// 앱에 번들된 서드파티 데이터/코드의 라이선스 고지.
/// 한자 입력 사전(hanja_single.txt)은 libhangul 프로젝트의 데이터를 사용하며,
/// 그 데이터 파일은 BSD 3-Clause 라이선스로 배포된다 (라이브러리 코드 자체의
/// LGPL-2.1과는 별개). BSD 라이선스는 배포본(바이너리)에도 저작권 고지를
/// 포함하도록 요구하므로 이 화면에 표시한다.
struct LicensesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("한자 입력 사전 데이터")
                        .font(.headline)

                    Link("libhangul", destination: URL(string: "https://github.com/libhangul/libhangul")!)
                        .font(.subheadline)

                    Text("음절별 한자 후보 데이터(data/hanja/hanja.txt)의 일부를 사용합니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Text(bsdLicenseText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
            .padding(20)
        }
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
    }

    private let bsdLicenseText = """
    Copyright (c) 2005,2006 Choe Hwanjin
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.
    3. Neither the name of the author nor the names of its contributors
       may be used to endorse or promote products derived from this software
       without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
    """
}

#Preview {
    NavigationStack {
        LicensesView()
    }
}
