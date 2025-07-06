// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyB5Ufc0N4WMuapF6z_tBesYDXQVZADs0RE",
  authDomain: "abdiwavee.firebaseapp.com",
  projectId: "abdiwavee",
  storageBucket: "abdiwavee.firebasestorage.app",
  messagingSenderId: "315443508332",
  appId: "1:315443508332:web:a3a3b5e0cb1bf6aea69449",
  measurementId: "G-92163MQQL8"
};

// Initialize Firebase
import { initializeApp } from 'firebase/app';
import { getAnalytics } from 'firebase/analytics';

const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);

export { firebaseConfig, app, analytics };