# 🎤HumanSpeech - Package🎤

`HumanSpeech` é um helper em Swift para transcrever voz em texto usando `SFSpeechRecognizer` e `AVAudioEngine`. O pacote facilita a integração de reconhecimento de fala em apps iOS e macOS.

---

## 🟡Visão Geral

- Coordena permissões de microfone e reconhecimento de fala (locale `"pt-BR"`).  
- Inicia e para captura de áudio.  
- Publica o texto transcrito em tempo real através de `transcript`.  

---

## 🟡Compatibilidade

- iOS 15+ (recomendado)  
- macOS 12+ (com microfone)

---

## 🟡Requisitos

- **Info.plist** deve conter:
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription`
- Frameworks:
  - `Speech`
  - `AVFoundation`

---

## 🟡Principais Variáveis

- `transcript`: String publicada com texto parcial/final.  
- `audioEngine`: Motor de áudio em execução.  
- `request`: Fluxo de buffers de áudio para o `SpeechRecognizer`.  
- `task`: Tarefa de reconhecimento em andamento.  
- `recognizer`: Reconhecedor configurado para `"pt-BR"`.

---

## 🟡Principais Métodos

- `startTranscribing()`: Inicia transcrição contínua.  
- `stopTranscribing()`: Encerra a captura após 1,5s de delay.  
- `resetTranscript()`: Limpa o texto e reseta estado interno.

---

## 🟡Como Usar

1. Crie uma instância de `SpeechRecognizer`.  
2. Garanta permissões (speech e microfone).  
3. Chame `startTranscribing()` para iniciar.  
4. Observe `transcript` (MainActor) para atualizar sua UI.  
5. Para encerrar, use `stopTranscribing()`.  
6. Para limpar a UI, use `resetTranscript()`.

---

## 🟡Exemplo Simples (SwiftUI)

```swift
@State private var texto = ""
let sr = SpeechRecognizer()

var body: some View {
    VStack {
        Text(texto)
        HStack {
            Button("Iniciar") { Task { await sr.startTranscribing() } }
            Button("Parar") { Task { await sr.stopTranscribing() } }
            Button("Limpar") { Task { await sr.resetTranscript() } }
        }
    }
    .task { for await t in sr.$transcript.values { texto = t } }
}


