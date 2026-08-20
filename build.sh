#!/bin/bash


git clone https://github.com/flutter/flutter.git --depth 1 --branch 3.44.7 $HOME/flutter
export PATH="$HOME/flutter/bin:$PATH"


flutter --version
flutter pub get
flutter build web --release
