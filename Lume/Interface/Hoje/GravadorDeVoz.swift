import AVFoundation
import Foundation
import Observation
import Speech

/// Captura voz e transforma-a em texto (pt-PT), preferindo o modelo local.
/// A voz é só outra forma de escrever: a interpretação continua no
/// interpretador de texto, e nada é gravado sem confirmação no cartão.
@Observable @MainActor
final class GravadorDeVoz {
    enum Estado: Equatable {
        case parado
        case aGravar
        case indisponivel(String)
    }

    private(set) var estado = Estado.parado
    private(set) var transcricao = ""

    private let motor = AVAudioEngine()
    private var pedido: SFSpeechAudioBufferRecognitionRequest?
    private var tarefa: SFSpeechRecognitionTask?

    var aGravar: Bool { estado == .aGravar }

    func alternar() async {
        if aGravar { parar() } else { await comecar() }
    }

    private func comecar() async {
        transcricao = ""

        let autorizacao = await withCheckedContinuation { continuacao in
            SFSpeechRecognizer.requestAuthorization { continuacao.resume(returning: $0) }
        }
        guard autorizacao == .authorized else {
            estado = .indisponivel("Autoriza o reconhecimento de voz nas Definições do iPhone.")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            estado = .indisponivel("Autoriza o microfone nas Definições do iPhone.")
            return
        }
        guard let reconhecedor = SFSpeechRecognizer(locale: FormatadorDeMoeda.localidade),
              reconhecedor.isAvailable else {
            estado = .indisponivel("O reconhecimento de voz não está disponível neste aparelho.")
            return
        }

        do {
            let sessao = AVAudioSession.sharedInstance()
            try sessao.setCategory(.record, mode: .measurement, options: .duckOthers)
            try sessao.setActive(true, options: .notifyOthersOnDeactivation)

            let pedido = SFSpeechAudioBufferRecognitionRequest()
            pedido.shouldReportPartialResults = true
            // Quando o modelo local existe, o áudio não sai do aparelho.
            pedido.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition
            self.pedido = pedido

            // O tap corre na thread de áudio; o pedido aceita buffers de
            // qualquer thread, daí o nonisolated(unsafe).
            nonisolated(unsafe) let pedidoDoTap = pedido
            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
                pedidoDoTap.append(buffer)
            }
            motor.prepare()
            try motor.start()
            estado = .aGravar

            tarefa = reconhecedor.recognitionTask(with: pedido) { [weak self] resultado, erro in
                let texto = resultado?.bestTranscription.formattedString
                let terminou = erro != nil || (resultado?.isFinal ?? false)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let texto { transcricao = texto }
                    if terminou, aGravar { parar() }
                }
            }
        } catch {
            estado = .indisponivel("Não consegui começar a gravar.")
            parar()
        }
    }

    func parar() {
        motor.stop()
        motor.inputNode.removeTap(onBus: 0)
        pedido?.endAudio()
        tarefa?.cancel()
        pedido = nil
        tarefa = nil
        estado = .parado
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
