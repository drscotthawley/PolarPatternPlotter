# Polar Pattern Plotter

Polar Pattern Plotter is an iOS app for measuring sound directivy patterns for loudspeakers and microphones.  The iOS binary is available for free download on the [App Store](https://appsto.re/us/Mfvadb.i): 
<a href="https://itunes.apple.com/us/app/polar-pattern-plotter/id1124159846?mt=8"><img src="http://www.scotthawley.com/ppp/app_store_badge.svg"></a>

Source code is provided here for those who'd like to help improve the functionality of the app for the good of the community.

[PPP Web Site](http://www.scotthawley.com/ppp/)

Paper accepted for publication in *The Physics Teacher*.  [Link to pre-print version on arXiv.org](https://arxiv.org/abs/1702.06072)

## Building

* Make sure you have Xcode installed.
* Clone the repo.
* Open the .xcworkspace file with Xcode, e.g. `$ open PolarPatternPlotter.xcworkspace`
* Choose "Run" from the "Build" dropdown, or just click the "Play" (▶️) button.

## Screenshots:

<img src="http://www.scotthawley.com/ppp/screenshot_real_sm57.jpg" width=200px>
<img src="http://www.scotthawley.com/ppp/screenshot_twospeakers_250hz_.PNG" width=200px>


## Features to be added (you can help!):
* A variable frequency-filter, to reject background noise and to allow simultaneous experiments (at different frequencies).  This may be added as early as March 1, 2017; check back later.
* Corrections to angular drift.  Currently there's a slider but it's not enabled.  The code for this isn't quite working and it's commented-out in the source.
* Interpolate / smooth the data, and do polar-harmonic decomposition
* Port it to Android


Author: Scott Hawley
