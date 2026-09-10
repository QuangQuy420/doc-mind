import { Link, Route, Routes } from 'react-router-dom';
import RequireAuth from './components/RequireAuth.tsx';
import DocumentsPage from './pages/DocumentsPage.tsx';
import HomePage from './pages/HomePage.tsx';
import MePage from './pages/MePage.tsx';

function App() {
  return (
    <main>
      <h1>DocMind</h1>
      <nav>
        <Link to="/">Home</Link>
        <Link to="/me">Me</Link>
        <Link to="/documents">Documents</Link>
      </nav>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route
          path="/me"
          element={
            <RequireAuth>
              <MePage />
            </RequireAuth>
          }
        />
        <Route
          path="/documents"
          element={
            <RequireAuth>
              <DocumentsPage />
            </RequireAuth>
          }
        />
        <Route path="*" element={<p>Page not found.</p>} />
      </Routes>
    </main>
  );
}

export default App;
