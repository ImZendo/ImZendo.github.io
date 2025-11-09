class VehicleLockpickGame {
    constructor() {
        this.gameMode = 'circle';
        this.gameDifficulty = 'medium';
        this.timeAllowed = 30000;
        this.timeRemaining = this.timeAllowed;
        this.gameIsRunning = false;
        this.currentLockPin = 0;
        this.totalLockPins = 5;
        this.attemptsAllowed = 3;
        this.currentAttemptNumber = 0;
        this.successfulChecks = 0;
        this.checksNeeded = 3;
        
        // How fast things move
        this.redLineSpeed = 1.0;
        this.skillCheckNeedleSpeed = 2.0;
        
        // Target zone settings
        this.targetZoneSize = 30; // how big the green zone is (in degrees)
        this.targetZoneLocation = 0; // where the green zone is positioned
        
        this.setupGame();
    }
    
    setupGame() {
        this.setupControls();
        this.adjustDifficultySettings();
        
        // Keep the game hidden until needed
        document.getElementById('lockpick-container').classList.add('hidden');
    }
    
    setupControls() {
        // Listen for player input
        document.addEventListener('keydown', (e) => {
            if (!this.gameIsRunning) return;
            
            if (e.code === 'Space' || e.code === 'Enter') {
                e.preventDefault();
                this.handleAction();
            } else if (e.code === 'Escape') {
                e.preventDefault();
                this.quitGame(false, 'Player cancelled the game');
            } else if (e.code === 'KeyT') {
                // Debug key - check if red line is in green zone
                e.preventDefault();
                if (this.gameIsRunning && this.gameMode === 'circle') {
                    console.log('🔍 Debug Check - Testing line position');
                    this.isPickerInSweetSpot();
                }
            }
        });
        
        // NUI Events
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.action) {
                case 'startLockpick':
                    this.beginLockpicking(data.config);
                    break;
                case 'endLockpick':
                    this.quitGame(false, 'Game ended');
                    break;
                case 'showNotificationPopup':
                    this.showNotificationPopup(data.type, data.title, data.message, data.duration);
                    break;
                case 'hideNotificationPopup':
                    this.hideNotificationPopup();
                    break;
            }
        });
    }
    
    adjustDifficultySettings() {
        const difficulties = {
            easy: { speed: 0.8, sweetSpotSize: 50, timeLimit: 45000 },
            medium: { speed: 1.0, sweetSpotSize: 30, timeLimit: 30000 },
            hard: { speed: 1.2, sweetSpotSize: 20, timeLimit: 20000 }
        };
        
        const config = difficulties[this.gameDifficulty];
        this.redLineSpeed = config.speed;
        this.skillCheckNeedleSpeed = config.speed * 2;
        this.targetZoneSize = config.sweetSpotSize;
        this.timeAllowed = config.timeLimit;
        this.timeRemaining = this.timeAllowed;
    }
    
    beginLockpicking(gameSettings = {}) {
        // Set up the game based on what was passed in
        this.gameMode = gameSettings.gameType || 'circle';
        this.gameDifficulty = gameSettings.difficulty || 'medium';
        this.totalLockPins = gameSettings.pins || 5;
        this.attemptsAllowed = gameSettings.maxAttempts || 3;
        
        this.adjustDifficultySettings();
        this.resetGameState();
        
        // Make the game visible
        document.getElementById('lockpick-container').classList.remove('hidden');
        
        // Set up the type of game we're playing
        this.setupGameType();
        
        // Get the timer going
        this.gameIsRunning = true;
        this.startGameTimer();
        
        // Create a new target zone for the player to hit
        this.createNewTargetZone();
        
        // Let the player know what's happening
        this.showNotificationPopup(
            'start',
            'Time to Pick This Lock',
            `Line up the red line with the green zone, then hit SPACE! Difficulty: ${this.gameDifficulty.charAt(0).toUpperCase() + this.gameDifficulty.slice(1)}`
        );
        
        console.log('🚀 Vehicle lockpicking game is now running');
        console.log(`📊 Difficulty: ${this.gameDifficulty} (Target zone: ${this.targetZoneSize}°)`);
    }
    
    setupGameType() {
        const circleGame = document.getElementById('circle-game');
        const skillcheckGame = document.getElementById('skillcheck-game');
        const circleInstructions = document.getElementById('circle-instructions');
        const skillcheckInstructions = document.getElementById('skillcheck-instructions');
        
        if (this.gameMode === 'circle') {
            circleGame.classList.remove('hidden');
            skillcheckGame.classList.add('hidden');
            circleInstructions.classList.remove('hidden');
            skillcheckInstructions.classList.add('hidden');
            
            this.setupCircleGame();
        } else if (this.gameMode === 'skillcheck') {
            circleGame.classList.add('hidden');
            skillcheckGame.classList.remove('hidden');
            circleInstructions.classList.add('hidden');
            skillcheckInstructions.classList.remove('hidden');
            
            this.setupSkillcheckGame();
        }
        
        // Update difficulty indicator
        document.getElementById('difficulty-indicator').textContent = `Difficulty: ${this.gameDifficulty.charAt(0).toUpperCase() + this.gameDifficulty.slice(1)}`;
        document.getElementById('difficulty-indicator').className = `difficulty ${this.gameDifficulty}`;
        
        // Update attempts
        this.updateAttempts();
    }
    
    setupCircleGame() {
        // Setup pins
        const pinsContainer = document.querySelector('.pins-container');
        pinsContainer.innerHTML = '';
        
        for (let i = 0; i < this.totalLockPins; i++) {
            const pin = document.createElement('div');
            pin.className = 'pin';
            pin.setAttribute('data-pin', i);
            
            const indicator = document.createElement('div');
            indicator.className = 'pin-indicator';
            pin.appendChild(indicator);
            
            pinsContainer.appendChild(pin);
        }
        
        // Setup picker animation
        const picker = document.getElementById('picker');
        const animationDuration = 3 / this.redLineSpeed; // seconds per full rotation
        picker.style.animationDuration = `${animationDuration}s`;
        
        // Initialize timing for collision detection
        this.initializePickerTiming(animationDuration);
    }
    
    initializePickerTiming(durationSeconds) {
        this.pickerAnimationDuration = durationSeconds * 1000; // convert to milliseconds
        this.pickerAnimationStart = Date.now();
        
        console.log(`Picker animation initialized: ${durationSeconds}s per rotation`);
    }
    
    setupSkillcheckGame() {
        // Setup attempts indicators
        const attemptsContainer = document.querySelector('.attempts-container');
        attemptsContainer.innerHTML = '';
        
        for (let i = 0; i < this.skillcheckRequired; i++) {
            const attempt = document.createElement('div');
            attempt.className = 'attempt';
            if (i === 0) attempt.classList.add('active');
            attempt.setAttribute('data-attempt', i);
            attemptsContainer.appendChild(attempt);
        }
        
        // Setup needle animation
        const needle = document.getElementById('skillcheck-needle');
        needle.style.animationDuration = `${2 / this.needleSpeed}s`;
        
        this.generateSkillcheckZone();
    }
    
    createNewTargetZone() {
        // Generate a completely random position for the green target zone (more challenging)
        this.targetZoneLocation = Math.floor(Math.random() * 360);
        
        // Add some additional randomization to make it less predictable
        const randomOffset = (Math.random() - 0.5) * 60; // Random offset ±30 degrees
        this.targetZoneLocation = (this.targetZoneLocation + randomOffset + 360) % 360;
        
        // Position the visual green zone
        const sweetSpot = document.getElementById('sweet-spot');
        sweetSpot.style.transform = `translate(0%, -50%) rotate(${this.targetZoneLocation}deg)`;
        
        // Set visual size - make it proportional to the actual collision size
        const visualWidth = Math.max(50, this.targetZoneSize * 1.5); // Make it visible
        sweetSpot.style.width = `${visualWidth}px`;
        
        // Restart the picker animation to ensure perfect synchronization
        this.restartPickerAnimation();
        
        console.log(`🎯 New target zone: ${this.targetZoneLocation.toFixed(1)}° (±${(this.targetZoneSize/2).toFixed(1)}°)`);
    }
    
    restartPickerAnimation() {
        const picker = document.getElementById('picker');
        if (!picker) return;
        
        // Remove animation temporarily
        picker.style.animation = 'none';
        
        // Force reflow to ensure the animation removal takes effect
        picker.offsetHeight;
        
        // Restart animation
        const animationDuration = 3 / this.redLineSpeed;
        picker.style.animation = `pickerRotate ${animationDuration}s linear infinite`;
        
        // Reset our timing calculation
        this.pickerAnimationStart = Date.now();
        
        console.log(`🔄 Picker animation restarted (${animationDuration}s per rotation)`);
    }
    
    generateSkillcheckZone() {
        const startAngle = Math.random() * 270; // Don't put it at the very end
        const endAngle = startAngle + this.targetZoneSize;
        
        const successZone = document.getElementById('skillcheck-success-zone');
        successZone.style.background = `conic-gradient(from 0deg, 
            transparent 0deg, 
            transparent ${startAngle}deg, 
            #4CAF50 ${startAngle}deg, 
            #4CAF50 ${endAngle}deg, 
            transparent ${endAngle}deg, 
            transparent 360deg)`;
        
        this.skillcheckStart = startAngle;
        this.skillcheckEnd = endAngle;
    }
    
    handleAction() {
        if (this.gameMode === 'circle') {
            this.handleCircleAction();
        } else if (this.gameMode === 'skillcheck') {
            this.handleSkillcheckAction();
        }
    }
    
    handleCircleAction() {
        // Use the collision detection
        if (this.isPickerInSweetSpot()) {
            console.log('🎉 SUCCESS: Perfect alignment!');
            this.pinSuccess();
        } else {
            console.log('❌ MISS: Try again!');
            this.pinFailed();
        }
    }
    
    handleSkillcheckAction() {
        const needle = document.getElementById('skillcheck-needle');
        const needleRotation = this.getCurrentRotation(needle);
        
        // Check if needle is in success zone
        const isInZone = needleRotation >= this.skillcheckStart && needleRotation <= this.skillcheckEnd;
        
        if (isInZone) {
            this.successfulChecks++;
            this.updateSkillcheckAttempts(this.successfulChecks - 1, 'success');
            
            if (this.successfulChecks >= this.checksNeeded) {
                this.quitGame(true, 'Lock picked successfully!');
            } else {
                // Generate new zone for next attempt
                this.generateSkillcheckZone();
                // Update active attempt
                const attempts = document.querySelectorAll('.attempt');
                attempts.forEach(a => a.classList.remove('active'));
                if (attempts[this.skillcheckSuccess]) {
                    attempts[this.skillcheckSuccess].classList.add('active');
                }
            }
        } else {
            this.currentAttemptNumber++;
            this.updateSkillcheckAttempts(this.successfulChecks, 'failed');
            
            if (this.currentAttemptNumber >= this.attemptsAllowed) {
                this.quitGame(false, 'Lockpick broke!');
            } else {
                this.generateSkillcheckZone();
            }
        }
    }
    
    pinSuccess() {
        const pin = document.querySelector(`[data-pin="${this.currentLockPin}"]`);
        pin.classList.add('completed');
        
        this.currentLockPin++;
        
        console.log(`✅ Pin ${this.currentLockPin} completed! (${this.currentLockPin}/${this.totalLockPins})`);
        
        // Send progress notification to client
        fetch(`https://${GetParentResourceName()}/lockpickProgress`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                pin: this.currentLockPin,
                total: this.totalLockPins,
                message: `Pin ${this.currentLockPin}/${this.totalLockPins} picked!`
            })
        }).catch(() => {}); // Ignore errors for non-essential notifications
        
        if (this.currentLockPin >= this.totalLockPins) {
            this.quitGame(true, 'Lock picked successfully!');
        } else {
            // Generate new target zone for next pin
            console.log(`🔄 Creating new target zone for pin ${this.currentLockPin + 1}...`);
            this.createNewTargetZone();
        }
    }
    
    pinFailed() {
        this.currentAttemptNumber++;
        
        console.log(`❌ Failed attempt ${this.currentAttemptNumber}/${this.attemptsAllowed}`);
        
        if (this.currentAttemptNumber >= this.attemptsAllowed) {
            this.quitGame(false, 'Lockpick broke!');
        } else {
            this.updateAttempts();
            // Generate new target zone after failure
            console.log(`🔄 Creating new target zone after failure...`);
            this.createNewTargetZone();
        }
    }
    
    updateAttempts() {
        const attemptsLeft = this.attemptsAllowed - this.currentAttemptNumber;
        document.getElementById('attempts-left').textContent = `Attempts: ${attemptsLeft}/${this.attemptsAllowed}`;
    }
    
    updateSkillcheckAttempts(index, result) {
        const attempt = document.querySelector(`[data-attempt="${index}"]`);
        if (attempt) {
            attempt.classList.remove('active');
            attempt.classList.add(result);
        }
    }
    
    getCurrentPickerRotation() {
        // Calculate current picker rotation based on animation timing
        if (!this.pickerAnimationStart || !this.pickerAnimationDuration) {
            return 0;
        }
        
        const elapsed = Date.now() - this.pickerAnimationStart;
        const cycles = elapsed / this.pickerAnimationDuration;
        const angle = (cycles % 1) * 360; // Get fractional part and convert to degrees
        
        return angle;
    }

    isPickerInSweetSpot() {
        const redLineAngle = this.getCurrentPickerRotation();
        const greenZoneAngle = this.targetZoneLocation;
        const tolerance = this.targetZoneSize / 2; // Half the target zone size as tolerance
        
        // Calculate the shortest angular distance between red line and green zone
        let angleDiff = Math.abs(redLineAngle - greenZoneAngle);
        if (angleDiff > 180) {
            angleDiff = 360 - angleDiff; // Handle wraparound
        }
        
        const isHit = angleDiff <= tolerance;
        
        console.log(`=== COLLISION CHECK ===`);
        console.log(`Red Line: ${redLineAngle.toFixed(1)}°`);
        console.log(`Green Zone: ${greenZoneAngle.toFixed(1)}° ± ${tolerance.toFixed(1)}°`);
        console.log(`Angular Difference: ${angleDiff.toFixed(1)}°`);
        console.log(`HIT: ${isHit}`);
        console.log(`=======================`);
        
        return isHit;
    }
    
    startGameTimer() {
        this.timerInterval = setInterval(() => {
            this.timeRemaining -= 100;
            
            const progress = (this.timeRemaining / this.timeAllowed) * 100;
            document.getElementById('timer-progress').style.width = `${Math.max(0, progress)}%`;
            
            const seconds = Math.ceil(this.timeRemaining / 1000);
            document.getElementById('timer-text').textContent = `${seconds}s`;
            
            if (this.timeRemaining <= 0) {
                this.quitGame(false, 'Time ran out!');
            }
        }, 100);
    }
    
    resetGameState() {
        this.currentLockPin = 0;
        this.currentAttemptNumber = 0;
        this.successfulChecks = 0;
        this.timeRemaining = this.timeAllowed;
        
        // Reset the visual interface
        document.querySelectorAll('.pin').forEach(pin => pin.classList.remove('completed'));
        document.querySelectorAll('.attempt').forEach(attempt => {
            attempt.classList.remove('active', 'success', 'failed');
        });
        
        // Reset the timer display
        document.getElementById('timer-progress').style.width = '100%';
        document.getElementById('timer-text').textContent = `${Math.ceil(this.timeAllowed / 1000)}s`;
    }
    
    quitGame(success, message) {
        this.gameIsRunning = false;
        
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
        }
        
        // Show notification popup (no need for overlay animation anymore)
        if (success) {
            this.showNotificationPopup(
                'success',
                'Vehicle Unlocked!',
                'You successfully picked the lock. You can now enter the vehicle.',
                5000
            );
        } else {
            this.showNotificationPopup(
                'failure',
                'Lockpicking Failed!',
                message || 'The lockpick attempt failed. Try again with better timing.',
                4000
            );
        }
        
        // Send result to client immediately (no delay needed)
        setTimeout(() => {
            this.hideUI();
            fetch(`https://${GetParentResourceName()}/lockpickResult`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    success: success,
                    message: message,
                    showPopup: true,
                    popupType: success ? 'success' : 'failure'
                })
            });
        }, 500); // Reduced from 2000ms to 500ms for faster response
    }
    

    
    hideUI() {
        document.getElementById('lockpick-container').classList.add('hidden');
    }

    // Popup notification system
    showNotificationPopup(type, title, message, duration = 4000) {
        const popup = document.getElementById('notification-popup');
        const icon = document.getElementById('notification-icon');
        const titleElement = document.getElementById('notification-title');
        const messageElement = document.getElementById('notification-message');

        // Set content
        icon.className = `notification-icon ${type}`;
        titleElement.textContent = title;
        messageElement.textContent = message;

        // Show popup
        popup.classList.remove('hidden', 'fade-out');
        
        // Auto-hide after duration
        setTimeout(() => {
            this.hideNotificationPopup();
        }, duration);
    }

    hideNotificationPopup() {
        const popup = document.getElementById('notification-popup');
        popup.classList.add('fade-out');
        
        // Hide completely after animation
        setTimeout(() => {
            popup.classList.add('hidden');
        }, 400);
    }
}

// Initialize the lockpicking game
const lockpickGame = new VehicleLockpickGame();

// Utility functions for NUI
function post(url, data) {
    return fetch(`https://${GetParentResourceName()}/${url}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data)
    });
}

// Close UI on escape (fallback)
document.addEventListener('keydown', function(e) {
    if (e.code === 'Escape' && !lockpickGame.isActive) {
        post('closeUI', {});
    }
});

console.log('Lockpick UI loaded successfully');