import type { Character, Unit } from '../types'

export const units: readonly Unit[] = [
  { id: 'quay', name: '岸壁班', nameEn: 'QUAY', color: '#4dd6ff' },
  { id: 'lantern', name: '灯火班', nameEn: 'LANTERN', color: '#ffb547' },
  { id: 'anchor', name: '錨班', nameEn: 'ANCHOR', color: '#ff5f8f' },
]

export const characters: readonly Character[] = [
  {
    id: 'ao',
    name: '汐見 蒼',
    nameEn: 'AO SHIOMI',
    unitId: 'quay',
    catchphrase: '迷ったら、まず海を見ろ。',
    description:
      '案内人歴3年。港のどの桟橋にも顔が利く。口数は少ないが、迷子の旅人を見つけるのがいちばん早い。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '22' },
      { label: '身長', value: '178cm' },
      { label: '担当区域', value: '第一桟橋' },
      { label: '好きなもの', value: '缶コーヒー' },
    ],
    palette: ['#0d2b4a', '#4dd6ff'],
  },
  {
    id: 'nagi',
    name: '瀬戸 凪',
    nameEn: 'NAGI SETO',
    unitId: 'quay',
    catchphrase: '静かな夜のほうが、声はよく届く。',
    description:
      '無線と海図を担当する記録係。深夜の航路変更をすべて頭に入れている。夜食を作るのが趣味。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '25' },
      { label: '身長', value: '171cm' },
      { label: '担当区域', value: '管制小屋' },
      { label: '好きなもの', value: '夜食づくり' },
    ],
    palette: ['#123a3a', '#7ef0c8'],
  },
  {
    id: 'hinata',
    name: '灯野 陽向',
    nameEn: 'HINATA AKARINO',
    unitId: 'lantern',
    catchphrase: '暗いなら、こっちが光ればいいだけだろ！',
    description:
      '最年少の案内人。声が大きく、走るのが速い。旅人の名前を一度で覚えることだけは誰にも負けない。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '18' },
      { label: '身長', value: '165cm' },
      { label: '担当区域', value: '待合室' },
      { label: '好きなもの', value: '屋台のたこ焼き' },
    ],
    palette: ['#5a2a00', '#ffb547' ],
  },
  {
    id: 'rui',
    name: '燈堂 累',
    nameEn: 'RUI TOUDOU',
    unitId: 'lantern',
    catchphrase: '順路は決めてある。あとは歩くだけだ。',
    description:
      '元・灯台守。段取りに厳しく、案内の手順書はすべて彼が書いた。後輩には甘い、と本人だけが気づいていない。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '29' },
      { label: '身長', value: '183cm' },
      { label: '担当区域', value: '灯台' },
      { label: '好きなもの', value: '万年筆' },
    ],
    palette: ['#4a2350', '#d9a3ff'],
  },
  {
    id: 'ikari',
    name: '碇 真尋',
    nameEn: 'MAHIRO IKARI',
    unitId: 'anchor',
    catchphrase: '荷物は預かる。心配ごとも、ついでに。',
    description:
      '倉庫番。重いものはすべて彼が運ぶ。旅人の忘れ物を保管する棚には、名前と日付が几帳面に並んでいる。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '27' },
      { label: '身長', value: '188cm' },
      { label: '担当区域', value: '第二倉庫' },
      { label: '好きなもの', value: '甘い缶詰' },
    ],
    palette: ['#511a2e', '#ff5f8f'],
  },
  {
    id: 'sui',
    name: '深水 翠',
    nameEn: 'SUI MIKUMI',
    unitId: 'anchor',
    catchphrase: '出航まで、あと少しだけ付き合ってよ。',
    description:
      '夜間だけ開く売店の店主で、非番の案内人。港の噂はまず彼女のカウンターに集まってくる。',
    cast: 'CV. ○○ ○○',
    profile: [
      { label: '年齢', value: '24' },
      { label: '身長', value: '160cm' },
      { label: '担当区域', value: '夜間売店' },
      { label: '好きなもの', value: 'ラジオ' },
    ],
    palette: ['#20304f', '#a8b6ff'],
  },
]
