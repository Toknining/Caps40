import { initializeApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  where,
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyCnxJboguDMIMvYL9-DEOOUlQ48QqUtOsk',
  authDomain: 'askuc-e1aba.firebaseapp.com',
  projectId: 'askuc-e1aba',
  storageBucket: 'askuc-e1aba.firebasestorage.app',
  messagingSenderId: '206861061946',
  appId: '1:206861061946:web:519fd91bb8c9f9a26d8a03',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

export async function checkForAdminAccount() {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'admin'));
  const snapshot = await getDocs(q);
  return !snapshot.empty;
}

export async function countStudents() {
  const usersRef = collection(db, 'students');
  const q = query(usersRef, where('role', '==', 'student'));
  const snapshot = await getDocs(q);
  return snapshot.size;
}

export async function createAdminAccount(email, password) {
  const userCredential = await createUserWithEmailAndPassword(
    auth,
    email,
    password,
  );

  const uid = userCredential.user.uid;

  await setDoc(
    doc(db, 'students', uid),
    {
      email: email.toLowerCase().trim(),
      role: 'admin',
      firstName: 'Admin',
      lastName: 'User',
      studentId: 'ADMIN',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );

  return userCredential.user;
}

export async function adminSignIn(email, password) {
  const userCredential = await signInWithEmailAndPassword(auth, email, password);
  const user = userCredential.user;

  const usersRef = collection(db, 'students');
  const q = query(
    usersRef,
    where('email', '==', user.email?.toLowerCase()),
  );
  const snapshot = await getDocs(q);

  if (snapshot.empty) {
    await signOut(auth);
    throw new Error('Your account is not a registered student account.');
  }

  const profile = snapshot.docs[0].data();

  if (profile.role !== 'admin') {
    await signOut(auth);
    throw new Error('This account does not have admin access.');
  }

  return user;
}

export { signOut as adminSignOut };
