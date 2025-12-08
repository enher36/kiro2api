/**
 * 登录页面控制器
 */
(function() {
    'use strict';

    // 页面加载时检查会话状态
    checkSession();

    // 绑定表单提交事件
    const form = document.getElementById('loginForm');
    if (form) {
        form.addEventListener('submit', handleLogin);
    }

    /**
     * 从 cookie 获取 CSRF token
     */
    function getCsrfToken() {
        const match = document.cookie.split('; ').find(row => row.startsWith('csrf_token='));
        return match ? decodeURIComponent(match.split('=')[1]) : '';
    }

    /**
     * 检查当前会话状态，如已登录则跳转到首页
     */
    async function checkSession() {
        try {
            const response = await fetch('/api/session');
            if (response.ok) {
                const data = await response.json();
                if (data.authenticated) {
                    window.location.href = '/';
                }
            }
        } catch (error) {
            // 忽略错误，继续显示登录页面
            console.debug('会话检查失败:', error);
        }
    }

    /**
     * 处理登录表单提交
     */
    async function handleLogin(event) {
        event.preventDefault();

        const username = document.getElementById('username').value.trim();
        const password = document.getElementById('password').value;
        const loginBtn = document.getElementById('loginBtn');
        const btnText = loginBtn.querySelector('.btn-text');
        const btnLoading = loginBtn.querySelector('.btn-loading');
        const errorEl = document.getElementById('errorMessage');

        // 隐藏错误信息
        errorEl.style.display = 'none';

        // 基本验证
        if (!username || !password) {
            showError('请输入用户名和密码');
            return;
        }

        // 显示加载状态
        setLoading(true);

        try {
            const csrfToken = getCsrfToken();
            const response = await fetch('/api/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                },
                body: JSON.stringify({ username, password })
            });

            const data = await response.json();

            if (response.ok && data.success) {
                // 登录成功，跳转到首页
                window.location.href = '/';
            } else {
                // 显示错误信息
                showError(data.error || '登录失败，请重试');
            }
        } catch (error) {
            console.error('登录请求失败:', error);
            showError('网络错误，请检查网络连接后重试');
        } finally {
            setLoading(false);
        }
    }

    /**
     * 显示错误信息
     */
    function showError(message) {
        const errorEl = document.getElementById('errorMessage');
        errorEl.textContent = message;
        errorEl.style.display = 'block';
    }

    /**
     * 设置加载状态
     */
    function setLoading(loading) {
        const loginBtn = document.getElementById('loginBtn');
        const btnText = loginBtn.querySelector('.btn-text');
        const btnLoading = loginBtn.querySelector('.btn-loading');

        loginBtn.disabled = loading;
        btnText.style.display = loading ? 'none' : 'inline';
        btnLoading.style.display = loading ? 'flex' : 'none';
    }
})();
