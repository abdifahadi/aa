import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class MessageList extends StatelessWidget {
  final List<MessageModel> messages;
  final ChatModel chat;
  final UserModel currentUser;
  final Function(MessageModel) onMessageLongPress;
  final FirebaseService firebaseService;

  const MessageList({
    Key? key,
    required this.messages,
    required this.chat,
    required this.currentUser,
    required this.onMessageLongPress,
    required this.firebaseService,
  }) : super(key: key);

  // Utility function to build message status icon
  Widget buildMessageStatusIcon(String status) {
    if (status == 'seen') {
      return const Icon(Icons.done_all, size: 18, color: Colors.blue);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 18, color: Colors.grey);
    } else if (status == 'sent') {
      return const Icon(Icons.done, size: 18, color: Colors.grey);
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isCurrentUser = message.senderId == currentUser.uid;
        return _buildMessageItem(context, message, isCurrentUser);
      },
    );
  }

  Widget _buildMessageItem(
      BuildContext context, MessageModel message, bool isCurrentUser) {
    final messageTime = DateFormat('h:mm a').format(message.timestamp);

    // Use different layouts based on message type
    return GestureDetector(
      onLongPress: () => onMessageLongPress(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser && message.senderName != null) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withAlpha(51),
                child: Text(message.senderName![0]),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Show sender name for group chats if needed
                  if (!isCurrentUser &&
                      message.senderName != null &&
                      chat.isGroup)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                  // Different container styles for media vs text messages
                  if (message.type == MessageType.text)
                    _buildTextMessageBubble(context, message, isCurrentUser)
                  else
                    _buildMediaMessageBubble(context, message, isCurrentUser),

                  // Timestamp and read indicators
                  const SizedBox(height: 4.0),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 4.0, left: 4.0, bottom: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          messageTime,
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(180),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        if (isCurrentUser)
                          buildMessageStatusIcon(
                              _getMessageStatusString(message.status)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Separate widget for text message bubbles
  Widget _buildTextMessageBubble(
      BuildContext context, MessageModel message, bool isCurrentUser) {
    final textContent = message.content;
    final textLength = textContent.length;

    // Calculate dynamic padding based on message length
    final horizontalPadding = textLength < 20 ? 12.0 : 10.0;
    final verticalPadding = textLength < 20 ? 10.0 : 8.0;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: IntrinsicWidth(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: Text(
            textContent,
            style: TextStyle(
              color: isCurrentUser
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // Separate widget for media message bubbles
  Widget _buildMediaMessageBubble(
      BuildContext context, MessageModel message, bool isCurrentUser) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withAlpha(230)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: _buildMediaWidget(message),
      ),
    );
  }

  Widget _buildMediaWidget(MessageModel message) {
    if (message.type == MessageType.image && message.mediaUrl != null) {
      return _buildImageWidget(message);
    } else if (message.type == MessageType.video && message.mediaUrl != null) {
      return _buildVideoWidget(message);
    } else if (message.type == MessageType.document) {
      return _buildDocumentWidget(message);
    } else {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Unavailable media'),
      );
    }
  }

  Widget _buildImageWidget(MessageModel message) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement full screen image view
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                message.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 220,
                    height: 200,
                    color: Colors.grey[300],
                    child: Center åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎP≤åéù¡C¡A¡'p{¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –ADÃ‹ PÄ‘ñò@H 0@4ë    , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Ak∞œ‹ PÄ‘ñò@H 0@4ë`Ã   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  D†Å  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎp∑åéù¡C¡A¡'@{¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –Aß±œ‹ PÄ‘ñò@H 0@4ë®Œ   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Aó´”‹ PÄ‘ñò@H 0@4ë–   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ¿Øåéù¡C¡A¡'@y¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –AÖ¨”‹ PÄ‘ñò@H 0@4ë8”   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Añ‰◊‹ PÄ‘ñò@H 0@4ëÄ’   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DÑÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ–∆åéù¡C¡A¡' {¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –AÉÂ◊‹ PÄ‘ñò@H 0@4ë»◊   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –A‹‘⁄‹ PÄ‘ñò@H 0@4ë⁄   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ`…åéù¡C¡A¡'@y¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –Aÿ’⁄‹ PÄ‘ñò@H 0@4ëX‹   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Añòﬂ‹ PÄ‘ñò@H 0@4ë†ﬁ   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DÑÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ`…åéù¡C¡A¡'0z¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –A‰ôﬂ‹ PÄ‘ñò@H 0@4ëË‡   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –A@…‚‹ PÄ‘ñò@H 0@4ë0„   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  D†Å  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎÀåéù¡C¡A¡'†|¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –A8 ‚‹ PÄ‘ñò@H 0@4ëxÂ   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Aı√Â‹ PÄ‘ñò@H 0@4ë¿Á   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  D†Å  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎp∑åéù¡C¡A¡'¿z¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –AËƒÂ‹ PÄ‘ñò@H 0@4ëÍ   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –AïÈ‹ PÄ‘ñò@H 0@4ëPÏ   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DºÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ∞¡åéù¡C¡A¡'êy¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –AbÈ‹ PÄ‘ñò@H 0@4ëòÓ   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Aµ$Ì‹ PÄ‘ñò@H 0@4ë‡   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ∞¡åéù¡C¡A¡'`{¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –Aû%Ì‹ PÄ‘ñò@H 0@4ë(Û   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –A˚›‹ PÄ‘ñò@H 0@4ëpı   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DºÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ∞¡åéù¡C¡A¡'Py¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –A4·‹ PÄ‘ñò@H 0@4ë∏˜   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅV  J  H  G± @   "N  Ä$ÄÄ ` –Af°Û‹ PÄ‘ñò@H 0@4I˙   , IsFullS creen():  (Tolera nceMode=1,  InPi xels=0,  ProcName =DRWUI.e xe, AppW indowWid†th=58 'a Height=2Monitorq&192 '%160&òsòq_DCS^SizeDDiv
bIs
ed=0)Ägò¬˚4õàyÅà  º"Å  åÿHOƒÅ `ıÉ  ùÑ#ÉdÒtx˚ ÇõÅÉ"áÄ   8á@ûäCáÎ∞¡åù«¡C¡A¡'@{¨√%¿Å"    H  ± @   "N  Ä$ÄÄ ` –An¢Û‹ PÄ‘ñò@H 0@4ëH¸   , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅX  L  H  I± @   "N  Ä$ÄÄ ` –Al›˜‹ PÄ‘ñò@H 0@4ëê˛   , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_DCS^SizeàDiv
bIs
 ed=0)Ägò¬h˚õàyÅà  DºÅ  åÿêOƒÅ `ıÉ  ùÑ#ÉdÒt˚ ÇõÅÉ"á@Ä  8á@ûäCáÎ øåéù¡C¡A¡'pz¨¬%¡Å"    H  ± @   "N  Ä$ÄÄ ` –AWﬂ˜‹ PÄ‘ñò@H 0@4ëÿ    , FullSc reenDete ctThread (): Notify>s>(Ev ent=1,PI D=13632, ProcName =DRWUI.exe,/=0,i swindowed Source =-1) success ~ Ñ†£õÅ úÌı™q˚

º`ÄpÚOƒÇÅÄ‘≠°dˆòÀ °EãÖ;`ÙÉ' \\. \DISPLAY1Ö	ˇ ¡ÅV  J  H  G± @   "N  Ä$ÄÄ ` –A¥Ü˚‹ PÄ‘ñò@H 0@4ë    , IsFull Screen() : (Toler anceMode=1,  InP ixels=0,  ProcNam e=DRWUI. exe, App WindowWi@dth=58 'aHeight=2Monito‚r&192 '%l10&òsòq_import tagTester from './_tagTester.js';
import isFunction from './isFunction.js';
import isArrayBuffer from './isArrayBuffer.js';
import { hasDataViewBug } from './_stringTagBug.js';

var isDataView = tagTester('DataView');

// In IE 10 - Edge 13, we need a different heuristic
// to determine whether an object is a `DataView`.
// Also, in cases where the native `DataView` is
// overridden we can't rely on the tag itself.
function alternateIsDataView(obj) {
  return obj != null && isFunction(obj.getInt8) && isArrayBuffer(obj.buffer);
}

export default (hasDataViewBug ? alternateIsDataView : isDataView);
                                                                                                                                    