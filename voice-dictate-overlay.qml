import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: window

    # Colors defined in MatugenColors.qml in same directory
    MatugenColors { id: mc }
    
    # Layer position above other windows
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    
    color: "transparent"
    mask: Region {}

    anchors {
        left: true
        right: true
        bottom: true
    }
    
    margins {
        bottom: 40
    }
    
    implicitHeight: 52

    # IPC interface to change state
    IpcHandler {
        target: "voice-dictate-overlay"
        
        function setState(stateName: string): void {
            currentState = stateName
        }
    }

    property string currentState: "recording"
    property var cavaValues: [0, 0, 0, 0, 0, 0, 0, 0]

    # Process CAVA output for real-time visualization
    Process {
        command: ["cava", "-p", "/tmp/cava-dictate.conf"]
        running: currentState === "recording"
        
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(';');
                if (parts.length >= 8) {
                    let newValues = [];
                    let alpha = 0.78;
                    for (let j = 0; j < 8; j++) {
                        let newVal = parseInt(parts[j]) || 0;
                        let prevVal = cavaValues[j] || 0;
                        let smoothed = (prevVal * alpha) + (newVal * (1 - alpha));
                        newValues.push(smoothed);
                    }
                    cavaValues = newValues;
                }
            }
        }
    }
    
    property real animPhase: 0
    
    Timer {
        id: globalAnimationTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            animPhase = (animPhase + 2.2) % 360
        }
    }

    onCurrentStateChanged: {
        if (currentState === "error") {
            shakeAnimation.start()
        }
        if (currentState === "success" || currentState === "error") {
            exitTimer.interval = currentState === "success" ? 800 : 1800
            exitTimer.start()
        }
    }

    # Error shake animation
    SequentialAnimation {
        id: shakeAnimation
        loops: 2
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: 12; duration: 100; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50; easing.type: Easing.InOutQuad }
    }

    Timer {
        id: exitTimer
        running: false
        onTriggered: {
            fadeOutAnimation.start()
        }
    }

    SequentialAnimation {
        id: fadeOutAnimation
        NumberAnimation { target: mainContainer; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutQuad }
        onStopped: {
            Qt.quit()
        }
    }

    Rectangle {
        id: mainContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenterOffset: 0
        
        width: contentRow.width + 24
        height: 40
        radius: 20
        
        Behavior on width {
            NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
        }

        color: Qt.rgba(mc.windowBgColor.r, mc.windowBgColor.g, mc.windowBgColor.b, 0.90)
        
        border.color: {
            if (currentState === "success") return mc.tertiary
            if (currentState === "error") return mc.error
            if (currentState === "muted") return "#ffd60a"
            return Qt.rgba(mc.primary.r, mc.primary.g, mc.primary.b, 0.30)
        }
        border.width: (currentState === "success" || currentState === "error") ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on border.width { NumberAnimation { duration: 200 } }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 0
            
            Rectangle {
                id: iconContainer
                width: 16
                height: 16
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                
                # Active recording dot
                Rectangle {
                    id: redDot
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: Qt.rgba(mc.error.r, mc.error.g * 0.3, mc.error.b * 0.3, 1.0)
                    visible: currentState === "recording"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(mc.error.r, mc.error.g * 0.3, mc.error.b * 0.3, 0.31)
                        border.width: 1.5

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: currentState === "recording"
                            PropertyAnimation { to: 1.5; duration: 1400; easing.type: Easing.OutQuad }
                            PropertyAnimation { to: 1.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: currentState === "recording"
                            PropertyAnimation { to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                            PropertyAnimation { to: 1.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                    }
                }

                # Microphone muted text icon
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.secondary
                    anchors.centerIn: parent
                    visible: currentState === "muted"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: currentState === "muted"
                        PropertyAnimation { to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
                        PropertyAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }

                # Transcribing loading icon
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.primary
                    anchors.centerIn: parent
                    visible: currentState === "transcribing"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1400
                        running: currentState === "transcribing"
                    }
                }

                # Success checkmark icon
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.tertiary
                    anchors.centerIn: parent
                    visible: currentState === "success"
                    
                    scale: visible ? 1.0 : 0.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                    
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                # Error alert icon
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.error
                    anchors.centerIn: parent
                    visible: currentState === "error"
                    
                    scale: visible ? 1.0 : 0.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                    
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            Item {
                id: waveSpacer
                width: (currentState === "recording" || currentState === "transcribing") ? 12 : 0
                height: 1
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }
            }

            # Loading progress bouncing dots
            Row {
                id: thinkingDots
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                width: (currentState === "transcribing") ? 23 : 0
                visible: width > 0
                clip: true
                
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: mc.primary
                        anchors.verticalCenter: parent.verticalCenter
                        
                        property real localPhase: animPhase
                        
                        opacity: {
                            let rad = localPhase * Math.PI / 180;
                            let val = Math.sin(rad * 6 - index * 1.5);
                            return Math.max(0.3, 0.75 + val * 0.25);
                        }
                        scale: {
                            let rad = localPhase * Math.PI / 180;
                            let val = Math.sin(rad * 6 - index * 1.5);
                            return Math.max(0.7, 1.0 + val * 0.3);
                        }
                    }
                }
            }

            # Frequency visualizer rows
            Row {
                id: waveRow
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                width: (currentState === "recording") ? 45 : 0
                visible: width > 0
                clip: true
                
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }

                Repeater {
                    model: 8
                    delegate: Rectangle {
                        width: 3
                        radius: 1.5
                        color: mc.primary
                        anchors.verticalCenter: parent.verticalCenter
                        
                        property real localPhase: animPhase
                        
                        height: {
                            if (currentState === "recording") {
                                let rad = localPhase * Math.PI / 180;
                                let i = index;
                                let idle = Math.sin(rad * 4 + i * 1.5) * 1.2 + 2.2;
                                let amplitude = cavaValues[i] || 0;
                                let voice = (amplitude / 100) * 16;
                                return Math.max(4, idle + voice);
                            } else {
                                return 4;
                            }
                        }
                        
                        Behavior on height {
                            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
