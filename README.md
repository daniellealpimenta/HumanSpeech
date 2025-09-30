# 🎤HumanSpeech - Package🎤

`HumanSpeech` é um helper em Swift para transcrever voz em texto usando `SFSpeechRecognizer` e `AVAudioEngine`. O pacote facilita a integração de reconhecimento de fala em apps iOS e macOS.

---

## 🔸Visão Geral

- Coordena permissões de microfone e reconhecimento de fala (locale `"pt-BR"`).  
- Inicia e para captura de áudio.  
- Publica o texto transcrito em tempo real através de `transcript`.  

---

## 🔸Compatibilidade

- iOS 15+ (recomendado)  
- macOS 12+ (com microfone)

---

## 🔸Requisitos

- **Info.plist** deve conter:
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription`
- Frameworks:
  - `Speech`
  - `AVFoundation`

---

## 🔸Principais Variáveis

- `transcript`: String publicada com texto parcial/final.  
- `audioEngine`: Motor de áudio em execução.  
- `request`: Fluxo de buffers de áudio para o `SpeechRecognizer`.  
- `task`: Tarefa de reconhecimento em andamento.  
- `recognizer`: Reconhecedor configurado para `"pt-BR"`.

---

## 🔸Principais Métodos

- `startTranscribing()`: Inicia transcrição contínua.  
- `stopTranscribing()`: Encerra a captura após 1,5s de delay.  
- `resetTranscript()`: Limpa o texto e reseta estado interno.

---

## 🔸Como Usar

1. Crie uma instância de `SpeechRecognizer`.  
2. Garanta permissões (speech e microfone).  
3. Chame `startTranscribing()` para iniciar.  
4. Observe `transcript` (MainActor) para atualizar sua UI.  
5. Para encerrar, use `stopTranscribing()`.  
6. Para limpar a UI, use `resetTranscript()`.

---

## 🔸Exemplo Simples (SwiftUI)

```swift
import SwiftUI
import HumanSpeech

struct ContentView: View {
    // Mantém uma instância do seu SpeechRecognizer no estado da view.
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    // Controla se a gravação está ativa ou não.
    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // Espaço para exibir o texto transcrito.
                Text("Texto Transcrito:")
                    .font(.headline)
                
                ScrollView {
                    Text(speechRecognizer.transcript)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray.opacity(0.5), lineWidth: 1)
                )

                // Botão principal que inicia ou para a detecção de voz.
                Button(action: toggleRecording) {
                    Text(isRecording ? "Parar Detecção" : "Iniciar Detecção de Voz")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isRecording ? Color.red : Color.blue)
                        .cornerRadius(16)
                }
                
                // Botão para limpar o texto transcrito.
                Button(action: {
                    speechRecognizer.resetTranscript()
                }) {
                    Text("Limpar Texto")
                }
                .disabled(speechRecognizer.transcript.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Detecção de Voz")
            .onDisappear {
                // Garante que a transcrição pare se a view desaparecer.
                if isRecording {
                    speechRecognizer.stopTranscribing()
                    isRecording = false
                }
            }
        }
    }
    
    /// Alterna o estado de gravação.
    private func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            speechRecognizer.startTranscribing()
        } else {
            speechRecognizer.stopTranscribing()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

