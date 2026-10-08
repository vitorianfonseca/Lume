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
        /// Falta autorizar o microfone ou o reconhecimento de voz — só se
        /// resolve nas Definições do iPhone.
        case semPermissao(String)
        /// Correu mal (aparelho sem reconhecimento, áudio, nada ouvido):
        /// pode tentar-se outra vez.
        case indisponivel(String)
    }

    private(set) var estado = Estado.parado
    private(set) var transcricao = ""
    /// O volume da voz, de 0 a 1, para o indicador de nível enquanto grava.
    private(set) var nivel: Double = 0

    private let motor = AVAudioEngine()
    private var pedido: SFSpeechAudioBufferRecognitionRequest?
    private var tarefa: SFSpeechRecognitionTask?

    var aGravar: Bool { estado == .aGravar }

    /// A mensagem do estado de erro ou de falta de permissão, se houver.
    var mensagem: String? {
        switch estado {
        case .semPermissao(let motivo), .indisponivel(let motivo): motivo
        case .parado, .aGravar: nil
        }
    }

    var semPermissao: Bool {
        if case .semPermissao = estado { return true }
        return false
    }

    func alternar() async {
        if aGravar { parar() } else { await comecar() }
    }

    /// Volta ao estado inicial (depois de um erro mostrado).
    func limpar() {
        guard !aGravar else { return }
        estado = .parado
        transcricao = ""
    }

    private func comecar() async {
        transcricao = ""
        nivel = 0

        let autorizacao = await withCheckedContinuation { continuacao in
            SFSpeechRecognizer.requestAuthorization { continuacao.resume(returning: $0) }
        }
        guard autorizacao == .authorized else {
            estado = .semPermissao("Para ditares registos, autoriza o reconhecimento de voz nas Definições.")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            estado = .semPermissao("Para ditares registos, autoriza o microfone nas Definições.")
            return
        }
        guard let reconhecedor = SFSpeechRecognizer(locale: FormatadorDeMoeda.localidade),
              reconhecedor.isAvailable else {
            estado = .indisponivel("O reconhecimento de voz não está disponível neste momento.")
            return
        }

        do {
            let sessao = AVAudioSession.sharedInstance()
            try sessao.setCategory(.record, mode: .measurement, options: .duckOthers)
            // Ativação assíncrona (iOS 27): não bloqueia a main thread.
            let ativou = await withCheckedContinuation { continuacao in
                sessao.activate(options: []) { sucesso, _ in continuacao.resume(returning: sucesso) }
            }
            guard ativou else { throw ErroDeAudio.sessaoInativa }

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
            // API do iOS 27: o tap é @Sendable e entrega um buffer só de
            // leitura; o Speech ainda pede um AVAudioPCMBuffer, daí a cópia.
            try entrada.installAudioTap(onBus: 0, bufferSize: 1024, format: formato) { [weak self] buffer, _ in
                let copia = AVAudioPCMBuffer(copying: buffer)
                pedidoDoTap.append(copia)
                // O volume mede-se aqui e só o número passa para a main thread.
                let volume = Self.nivel(de: copia)
                Task { @MainActor [weak self] in self?.atualizarNivel(volume) }
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
                    // Terminou sozinho (silêncio ou erro) sem ter ouvido nada.
                    if terminou, aGravar {
                        parar()
                        if transcricao.isEmpty {
                            estado = .indisponivel("Não consegui ouvir nada. Fala um pouco mais perto do iPhone.")
                        }
                    }
                }
            }
        } catch {
            parar()
            estado = .indisponivel("Não consegui começar a gravar.")
        }
    }

    func parar() {
        motor.stop()
        motor.inputNode.removeTap(onBus: 0)
        pedido?.endAudio()
        tarefa?.cancel()
        pedido = nil
        tarefa = nil
        nivel = 0
        estado = .parado
        AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { _, _ in }
    }

    /// Só atualiza quando a diferença se nota, para não redesenhar o ecrã
    /// a cada buffer (~47 por segundo).
    private func atualizarNivel(_ novo: Double) {
        guard aGravar, abs(novo - nivel) > 0.04 else { return }
        nivel = novo
    }

    /// RMS do buffer em decibéis, mapeado de −50 dB (silêncio) a −10 dB (voz alta).
    nonisolated private static func nivel(de buffer: AVAudioPCMBuffer) -> Double {
        guard let canal = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let amostras = Int(buffer.frameLength)
        var soma: Float = 0
        for indice in 0..<amostras {
            soma += canal[indice] * canal[indice]
        }
        let rms = (soma / Float(amostras)).squareRoot()
        let decibeis = 20 * log10(max(Double(rms), 1e-7))
        return min(max((decibeis + 50) / 40, 0), 1)
    }
}

private enum ErroDeAudio: Error {
    case sessaoInativa
}
