import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? heroTag;
  final bool isNetworkVideo;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    this.heroTag,
    this.isNetworkVideo = true,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      // Initialize video player controller
      if (widget.isNetworkVideo) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(
          File(widget.videoUrl),
        );
      }

      await _videoPlayerController.initialize();

      // Initialize Chewie controller for better video controls
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: false,
        controlsSafeAreaMinimum: const EdgeInsets.all(12.0),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error playing video',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Download'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading video',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializePlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const Center(
        child: Text(
          'Video player not initialized',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    Widget videoPlayer = Chewie(controller: _chewieController!);

    // Wrap with Hero widget if heroTag is provided
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: videoPlayer,
      );
    }

    return videoPlayer;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _shareVideo();
        break;
      case 'download':
        _downloadVideo();
        break;
    }
  }

  void _shareVideo() {
    // Implement video sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality not implemented yet'),
      ),
    );
  }

  void _downloadVideo() {
    // Implement video download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality not implemented yet'),
      ),
    );
  }
}

// Thumbnail widget for video preview
class VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const VideoThumbnail({
    Key? key,
    required this.videoUrl,
    this.width,
    this.height,
    this.onTap,
  }) : super(key: key);

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeThumbnail();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeThumbnail() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      
      await _controller.initialize();
      
      // Seek to a frame for thumbnail
      await _controller.seekTo(const Duration(seconds: 1));
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitialized && !_hasError)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: VideoPlayer(_controller),
              )
            else if (_hasError)
              const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 32,
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            // Play button overlay
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 48,
              ),
            ),
            // Duration overlay (if available)
            if (_isInitialized && !_hasError)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(str, length) {
    return padding(length) + str;
}

function padRight(str, length) {
    return str + padding(length);
}

function findMaxLength(arr) {
    let max = 0;

    arr.forEach(({length}) => {
        if (length > max) {
            max = length;
        }
    });

    return max;
}

function concatWithMaxLength(items, maxLength) {
    let result = '';

    // to prevent endless loops, always use the first item, regardless of length
    result += items.shift();

    while ( items.length && (result.length + items[0].length < maxLength) ) {
        result += ` ${items.shift()}`;
    }

    return result;
}

// we want to format names and descriptions like this:
// |    -f, --foo    Very long description very long description very long    |
// |                 description very long description.                       |
function formatHelpInfo({names, descriptions}) {
    const MARGIN_LENGTH = 4;
    const results = [];

    const maxLength = process.stdout.columns;
    const maxNameLength = findMaxLength(names);
    const wrapDescriptionAt = maxLength - (MARGIN_LENGTH * 3) - maxNameLength;

    // build the string for each option
    names.forEach((name, i) => {
        let result;
        let partialDescription;
        let words;

        // add a left margin to the name
        result = padLeft(names[i], MARGIN_LENGTH);
        // and a right margin, with extra padding so the descriptions line up with one another
        result = padRight(result, maxNameLength - names[i].length + MARGIN_LENGTH);

        // split the description on spaces
        words = descriptions[i].split(' ');
        // add as much of the description as we can fit on the first line
        result += concatWithMaxLength(words, wrapDescriptionAt);
        // if there's anything left, keep going until we've consumed the description
        while (words.length) {
            partialDescription = padding( maxNameLength + (MARGIN_LENGTH * 2) );
            partialDescription += concatWithMaxLength(words, wrapDescriptionAt);
            result += `\n${partialDescription}`;
        }

        results.push(result);
    });

    return results;
}

/**
 * A parser to interpret the key-value pairs entered on the command line.
 *
 * @alias module:jsdoc/opts/argparser
 */
class ArgParser {
    /**
     * Create an instance of the parser.
     */
    constructor() {
        this._options = [];
        this._shortNameIndex = {};
        this._longNameIndex = {};
    }

    _getOptionByShortName(name) {
        if (hasOwnProp.call(this._shortNameIndex, name)) {
            return this._options[this._shortNameIndex[name]];
        }

        return null;
    }

    _getOptionByLongName(name) {
        if (hasOwnProp.call(this._longNameIndex, name)) {
            return this._options[this._longNameIndex[name]];
        }

        return null;
    }

    _addOption(option) {
        let currentIndex;

        const longName = option.longName;
        const shortName = option.shortName;

        this._options.push(option);
        currentIndex = this._options.length - 1;

        if (shortName) {
            this._shortNameIndex[shortName] = currentIndex;
        }
        if (longName) {
            this._longNameIndex[longName] = currentIndex;
        }

        return this;
    }

    /**
     * Provide information about a legal option.
     *
     * @param {character} shortName - The short name of the option, entered like: -T.
     * @param {string} longName - The equivalent long name of the option, entered like: --test.
     * @param {boolean} hasValue - Does this option require a value? Like: -t templatename
     * @param {string} helpText - A brief description of the option.
     * @param {boolean} [canHaveMultiple=false] - Set to `true` if the option can be provided more
     * than once.
     * @param {function} [coercer] - A function to coerce the given value to a specific type.
     * @return {this}
     * @example
     * myParser.addOption('t', 'template', true, 'The path to the template.');
     * myParser.addOption('h', 'help', false, 'Show the help message.');
     */
    addOption(shortName, longName, hasValue, helpText, canHaveMultiple = false, coercer) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            hasValue: hasValue,
            helpText: helpText,
            canHaveMultiple: canHaveMultiple,
            coercer: coercer
        });
    }

    // TODO: refactor addOption to accept objects, then get rid of this method
    /**
     * Provide information about an option that should not cause an error if present, but that is always
     * ignored (for example, an option that was used in previous versions but is no longer supported).
     *
     * @private
     * @param {string} shortName - The short name of the option with a leading hyphen (for example,
     * `-v`).
     * @param {string} longName - The long name of the option with two leading hyphens (for example,
     * `--version`).
     */
    addIgnoredOption(shortName, longName) {
        return this._addOption({
            shortName: shortName,
            longName: longName,
            ignore: true
        });
    }

    /**
     * Generate a summary of all the options with corresponding help text.
     * @returns {string}
     */
    help() {
        const options = {
            names: [],
            descriptions: []
        };

        this._options.forEach(option => {
            let name = '';

            // don't show ignored options
            if (option.ignore) {
                return;
            }

            if (option.shortName) {
                name += `-${option.shortName}${option.longName ? ', ' : ''}`;
            }

            if (option.longName) {
                name += `--${option.longName}`;
            }
        });
    }
}

/**
 * Parse the command line arguments.
 * @module jsdoc/opts/argparser
 */
const _ = require('underscore');
const util = require('util');

const hasOwnProp = Object.prototype.hasOwnProperty;

function padding(length) {
    return new Array(length + 1).join(' ');
}

function padLeft(