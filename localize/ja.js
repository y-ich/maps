var localizedStrings = {};

localizedStrings['Maps'] = 'マップ';
localizedStrings['Replace Pin'] = 'ピンを置き換え';
localizedStrings['Print'] = 'プリント';
localizedStrings['Show Traffic'] = '渋滞状況を表示';
localizedStrings['Hide Traffic'] = '渋滞状況を隠す';
localizedStrings['Show Panoramio'] = 'Panoramioを表示';
localizedStrings['Hide Panoramio'] = 'Panoramioを隠す';
localizedStrings['Standard'] = '標準';
localizedStrings['Satellite'] = '航空写真';
localizedStrings['Hybrid'] = '地図+写真';
localizedStrings['List'] = 'リスト';
localizedStrings['Clear'] = '消去';
localizedStrings['Search'] = '検索';
localizedStrings['Directions'] = '経路';
localizedStrings['Route'] = '経路';
localizedStrings['Search: '] = '検索: ';
localizedStrings['Done'] = '完了';
localizedStrings['Search or Address'] = '検索または住所';
localizedStrings['Edit'] = '編集';
localizedStrings['Start'] = '出発';
localizedStrings['Start: '] = '出発: ';
localizedStrings['End: '] = '到着: ';
localizedStrings['Choose a bookmark to view on the map'] = 'マップ上に表示するブックマークを選択';
localizedStrings['Choose a recent search'] = '検索履歴を選択';
localizedStrings['Bookmarks'] = 'ブックマーク';
localizedStrings['Recents'] = '履歴';
localizedStrings['Contacts'] = '連絡先';
localizedStrings['Map'] = 'マップ';
localizedStrings['Info'] = '情報';
localizedStrings['address'] = '住所';
localizedStrings['Directions To Here'] = 'ここへの道順';
localizedStrings['Directions From Here'] = 'ここからの道順';
localizedStrings['Remove Pin'] = 'ピンを削除';
localizedStrings['Add to Contacts'] = '連絡先に追加';
localizedStrings['Share Location'] = '場所を送信';
localizedStrings['Add to Bookmarks'] = 'ブックマークに追加';
localizedStrings['Type a name for the bookmark'] = 'ブックマークの名前を入力';
localizedStrings['Cancel'] = 'キャンセル';
localizedStrings['Add Bookmark'] = '追加';
localizedStrings['Save'] = '保存';
localizedStrings['day'] = '日';
localizedStrings['days'] = '日';
localizedStrings['hour'] = '時間';
localizedStrings['hours'] = '時間';
localizedStrings['minute'] = '分';
localizedStrings['minutes'] = '分';
localizedStrings['Done'] = '完了';
localizedStrings['Current Location'] = '現在地';
localizedStrings['Dropped Pin'] = 'ドロップされたピン';
localizedStrings['No information'] = '情報なし';
localizedStrings['Clear All Recents'] = 'すべての履歴を消去';
localizedStrings['Directions Not Available\nDirections could not be found between these locations.'] = '経路が見つかりません\n2地点間の経路が見つかりませんでした。';
localizedStrings['Driving directions could not be found between these locations'] = '2地点間の運転経路が見つかりませんでした';
localizedStrings['Transit directions could not be found between these locations'] = '2地点間の運行経路が見つかりませんでした';
localizedStrings['Walking directions could not be found between these locations'] = '2地点間の徒歩経路が見つかりませんでした';
localizedStrings['There are no street views near here.'] = '近くにストリートビューが見つかりませんでした。';
localizedStrings['Sorry, an error occurred.'] = 'すいません、エラーが起こりました。';
localizedStrings['No Results Found'] = '結果が見つかりません';

var getRouteIndexMessage = function(index, total) {
    return '候補経路：全' + total +'件中' +(index + 1) + '件目';
}

var getDepartAtMessage = function(time) {
    return time + 'に出発';
}

var getArriveAtMessage = function(time) {
    return time + 'に到着';
}
