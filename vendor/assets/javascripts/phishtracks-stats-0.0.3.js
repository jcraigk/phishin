/**
 * phishtracks-stats.js
 * PhishTracks Stats Client
 *
 * by Alex Bird
 * 2014-06-19
 *
 * This is v0.0.3.
 *
 * Changelog:
 *
 * v0.0.3 - 2014-07-01
 * - don't require play data fields the server doesn't require
 * - make it clear which errors are client-side
 * - don't check for duplicate plays if no track_duration
 *
 * v0.0.2 - 2014-07-01
 * - add testMode option
 *
 * v0.0.1 - 2014-06-19
 * - initial release
 *
 */

(function() {

  window.PhishTracksStats = (function() {
    var PhishTracksStats = {};
    var _setup = false;
    var _lastPlayData = null;

    var _validateSetup = function() {
      if (_setup == false) {
        console.error('PhishTracksStats.setup() must be called');
        return false;
      }
      return true;
    };

    var _validatePlayData = function(playData, error) {
      if (playData === undefined) {
          if (error) {
            error({ message: '[phishtracks-stats client lib] playData is required' });
          }
          return false;
      }

      var fields = ['track_id', 'streaming_site'];

      for (var i = 0; i < fields.length; i++) {
        var field = fields[i];

        if (playData[field] === undefined) {
          if (error) {
            error({ message: '[phishtracks-stats client lib] ' + field + ' is required' });
          }
          return false;
        }
      }

      return true;
    };

    var _setlastPlayData = function(pd, dur) {
      _lastPlayData = { playData: pd, duration: dur, ts: (new Date).getTime() };
    };

    var _ignoreDoublePlay = function(newPd) {
      if (_lastPlayData && _lastPlayData.duration != null) {
        var t_diff = (new Date).getTime() - _lastPlayData.ts;
        return newPd.track_slug === _lastPlayData.playData.track_slug &&
               newPd.show_date === _lastPlayData.playData.show_date &&
               t_diff <= _lastPlayData.duration;
      }

      return false;
    };

    PhishTracksStats.setup = function(options) {
      _setup = true;
      PhishTracksStats.auth     = options.auth;
      PhishTracksStats.urlBase  = options.urlBase  || 'https://www.phishtrackstats.com';
      PhishTracksStats.testMode = options.testMode || false;
    };

    /**
     * @param playData play data to post
     * @param success  success callback. Response body object passed as only arg.
     * @param error    error callback. Response body object passed as only arg.
     */
    PhishTracksStats.postPlay = function(playData, success, error) {
      if (!_validateSetup()) {
        return;
      }

      if (!_validatePlayData(playData, error)) {
        return;
      }

      var duration = playData.track_duration;
      delete playData.track_duration;

      if (_ignoreDoublePlay(playData)) {
        if (error) {
          error({ message: '[phishtracks-stats client lib] ignoring double play' });
        }
        return;
      }

      var payload = { play_event: playData };

      if (PhishTracksStats.testMode) {
        payload.test_mode = true;
      }

      $.ajax({
        type: 'POST',
        url: PhishTracksStats.urlBase + '/api/v2/plays.json',
        processData: false,
        contentType: 'application/json',
        headers: {
          'Authorization': 'Basic ' + PhishTracksStats.auth
        },
        data: JSON.stringify(payload)
      })
      .done(function(data) {
        _setlastPlayData(playData, duration);

        if (success) {
          success(data);
        }
      })
      .fail(function(data) {
        console.error('PhishTracksStats server-side error');
        console.error(data.responseJSON);

        if (error) {
          error(data.responseJSON);
        }
      });
    };

    return PhishTracksStats;
  })();

}).call(this);
