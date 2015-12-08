# ConversationKit

### Quickly add CloudKit-based chats to any iOS app

copyright 2015, Stand Alone, Inc. & Ben Gottlieb

Instructions for Use:


* Download the project and build the "Combined Framework" target
* This will generate a ConversationKit.framework
* Add ConversationKit.framework to your project, and make sure it's copied to your bundle at build time (this may require adding a Run Script step to your Build Phases in your target. See the Test Harness target in the project for an example)
* On the Apple Developer Portal, ensure that you've got iCloud support with CloudKit (check the "Include CloudKit support (requires Xcode 6)" checkbox)
* In your app's Capabilities pane in Xcode…
  * Turn on "iCloud" and check the "CloudKit" checkbox (use default container is already selected)
  * Turn on "Background Modes" and check the "Remote Notifications" checkbox
* In your app delegate add `ConversationKit.configureNotifications(_:)` to your `applicationDidFinishLaunching(…)` method
* Add an `application(application,didReceiveRemoteNotification,fetchCompletionHandler)` method, and call the same method on `ConversationKit`
* If you want the user to be able to reply to message notifications from outside the application, add an `application(application,handleActionWithIdentifier,forLocalNotification,withResponseInfo,completionHandler)` method, and call the same method on `ConversationKit`
* Finally, call `ConversationKit.setupLocalSpeaker()` with an identifier for the local user.

You're now set up. You can easily add a `ConversationView` to a view controller, set its `conversation` property, and you'll receive messages as they come in.

ConversationKit caches all data in a local CoreData database (stored in ~/Library/Caches/Conversations.db by default). It also caches all images (from avatars) in ~/Library/Caches/Images.

## Main Interface
There is a ConversationKit object at the center of most of your interactions with ConversationKit. It's accessed via `ConversationKit.instance`.

Properties:

* `feedbackLevel` an enum controlling how much feedback you get when calling ConversationKit methods. Set to either `.Development`, `.Testing`, or `.Production`
* `showNetworkActivityIndicatorBlock` a closure that takes a single Bool, whether to show the Activity Indicator in the status bar. By default, it merely toggles it on and off, but youcan set a custom block to integrate with other Activity Indicator controls
* `cloudAvailable` is CloudKit available (the user may be signed in or not)

Methods:

* `configureNotifications(…)` is called from `didFinishLaunching(…)` to request permission to show notifications
* `application(application,didReceiveRemoteNotification,fetchCompletionHandler)` called from the identically named Application Delegate method to process incoming notifications
* `fetchAccountIdentifier(…)` takes a completion block which will be passed the user's CloudKit account identifier.
* `setup(containerName,completion)` called before accessing most other ConversationKit methods. The containerName is optional, and the completion block will be called with a Bool indicating success
* `setupLocalSpeaker(identifier, completion)` changes the identity of the local speaker. Called whenever the identity of the local speaker changes (new iCloud login, new GameCenter ID, etc). Calling with the existing identitfier does nothing. If necessary, will call `clearAllCachedDataWithCompletion()`
* `clearAllCachedDataWithCompletion(…)` clears out the CoreData cache and all in-memory caches.

## Objects

### Speaker
This object represents a user of the app, either the local user (`Speaker.localSpeaker`) or whomever they're speaking to.

Speakers have the following properties:

* `name` The user visible name that is shown to other speakers
* `identifier` a unique string. Frequently their CloudKit account identifier (can be found using `ConversationKit.fetchAccountIdentifier()`) or their GameCenter identifier
* `tags` an array of strings that can be used to search for users using the `SpeakerQuery` object
* `isLocalSpeaker` a boolean indicating whether this is the local device user's speaker
* `avatarImage` a UIImage representing the speaker and shown to other users
* `avatarImageLocalURL` a file URL pointing to the user's avatar image
* `speakerRef` a string representation of the user which can be stored and passed back to the `Speaker.speakerFromSpeakerRef` method

A few useful methods:
* `sendMessage(content, completion)` send the user a message


There are also a few class methods and vars on the Speaker object:

* `allKnownSpeakers` an array of Speakers representing all speakers the local speaker has either had a conversation with or found via a `SpeakerQuery` search
* `maxImageSize` a CGSize that all avatarImages will be capped to. Defaults to 100x100

Speakers are cached in the CoreData database as Speaker objects, and stored in CloudKit as ConversationKitSpeaker records.


### Message
A message represents a single message from one Speaker to another.

Properties:

* `content` a string containing the message text
* `speaker` a `Speaker`, who said it
* `listender` a `Speaker`, who it was said to
* `spokenAt` an NSDate, when it was spoken
* `conversation` a `Conversation` object (see below) representing all `Message`s between these two `Speaker`s

Messages are cached in the CoreData database as Message objects, and stored in CloudKit as ConversationKitMessage records.

### Conversation
A `Conversation` contains all `Message`s between two `Speaker`s.

* `startedBy` the `Speaker` that initiated the conversation
* `joinedBy` a `Speaker`, the other side of the conversation
*  `sortedMessages` a chronologically ordered list of `Message`s
*  `nonLocalSpeaker` whichever member of the conversation is NOT the localSpeaker

Class methods:

* `existingConversationWith(Speaker)`  looks up and returns an existing conversation between the local speaker and the passed in one
* `conversationWith(Soeaker)` looks up existing and creates a new one if needed
