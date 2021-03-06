//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import AVKit
import AppKit
import MacGestures


class PlayerViewController: MediaViewController, PlayerControlDelegate {
    static let storyboard = "Player"

    @IBOutlet private weak var playerView: AVPlayerView!
    @IBOutlet private weak var playerControl: PlayerControl!
    @IBOutlet private weak var playerStateImageView: NSImageView!

    private var audioPlayer: AKPlayer?

    private struct Constants {
        static let audioSyncInterval = 1.0/10.0
    }


    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPlayer()
        setupGestures()
        animateViewIn()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window {
            audioPlayer?.location = horizontalPosition(of: window)
        }
        audioPlayer?.volume = playerControl.volume.gain
        playerControl.toggle()
    }


    // MARK: Overrides

    override func resetCloseWindowTimer() {
        closeWindowTimer?.invalidate()
        if playerControl.state != .playing {
            super.resetCloseWindowTimer()
        }
    }

    override func handleWindowPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, let window = view.window, !animating else {
            return
        }

        switch pan.state {
        case .began:
            parentDelegate?.controllerDidMove(self)
        case .recognized, .momentum:
            var origin = window.frame.origin
            origin += pan.delta.round()
            window.setFrameOrigin(origin)
            audioPlayer?.location = horizontalPosition(of: window)
        case .possible:
            WindowManager.instance.checkBounds(of: self)
        default:
            return
        }
    }

    override func close() {
        parentDelegate?.controllerDidClose(self)
        WindowManager.instance.closeWindow(for: self)
        audioPlayer?.disconnect()
    }

    override func updateFromParent(frame: CGRect, animate: Bool) {
        super.updateFromParent(frame: frame, animate: animate)
        if let window = view.window {
            audioPlayer?.location = horizontalPosition(of: window)
        }
    }


    // MARK: Setup

    private func setupPlayer() {
        guard media.type == .video else {
            return
        }

        let url = Configuration.localMediaURLs ? media.localURL : media.url
        let controller = AudioController.shared
        audioPlayer = controller.play(url: url)

        var clock: CMClock?
        CMAudioDeviceClockCreate(allocator: nil, deviceUID: nil, clockOut: &clock)

        let player = AVPlayer(url: url)
        player.masterClock = clock
        player.isMuted = true
        playerView.player = player

        playerControl.player = player
        playerControl.gestureManager = gestureManager
        playerControl.tintColor = media.tintColor
        playerControl.delegate = self

        playerStateImageView.wantsLayer = true
        playerStateImageView.layer?.cornerRadius = playerStateImageView.frame.width / 2
        playerStateImageView.layer?.backgroundColor = style.darkBackground.cgColor
    }

    private func playAudio() {
        guard let player = playerView.player, playerControl.state != .playing else {
            return
        }

        let loadTime = 0.5 as TimeInterval // Time to give the video and audio to load, in seconds
        let hostTime = mach_absolute_time() + UInt64(loadTime * TimeInterval(NSEC_PER_SEC))

        // Play video
        player.setRate(1, time: CMTime.invalid, atHostTime: CMClockMakeHostTimeFromSystemUnits(hostTime))

        // Play audio
        audioPlayer?.start(at: AVAudioTime(hostTime: hostTime))
    }

    private func setupGestures() {
        let singleFingerPlayerTap = TapGestureRecognizer()
        gestureManager.add(singleFingerPlayerTap, to: playerView)
        singleFingerPlayerTap.gestureUpdated = { [weak self] gesture in
            self?.didTapVideoPlayer(gesture)
        }
    }


    // MARK: Gesture Handling

    private func didTapVideoPlayer(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, tap.state == .ended, !animating else {
            return
        }

        playerControl.toggle()
    }


    // MARK: IB-Actions

    @IBAction func closeButtonTapped(_ sender: Any) {
        animateViewOut()
    }


    // MARK: PlayerControlDelegate

    func playerChangedState(_ state: PlayerState) {
        if let image = state.image {
            playerStateImageView.image = image
        }

        let playerStateAlpha: CGFloat = state == .playing ? 0 : 1
        NSAnimationContext.runAnimationGroup({ [weak self] _ in
            NSAnimationContext.current.duration = 1
            self?.playerStateImageView.animator().alphaValue = playerStateAlpha
        })

        resetCloseWindowTimer()

        if state == .playing {
            playAudio()
        }
    }

    func playerChangedVolume(_ state: VolumeLevel) {
        audioPlayer?.volume = state.gain
    }


    // MARK: Helpers

    /// Returns the player's horizontal location inside the application's frame from 0 -> 1
    func horizontalPosition(of window: NSWindow) -> Double {
        let sortedScreens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }.dropFirst()
        guard let minX = sortedScreens.first?.frame.minX, let maxX = sortedScreens.last?.frame.maxX else {
            return 0
        }

        return Double((window.frame.midX - minX) / (maxX - minX))
    }
}
